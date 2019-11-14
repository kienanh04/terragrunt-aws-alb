provider "aws" {
  region  = "${var.aws_region}"
  profile = "${var.aws_profile}"
}

terraform {
  backend "s3" {}
}

data "terraform_remote_state" "vpc" {
  backend = "s3"

  config {
    bucket         = "${var.tfstate_bucket}"
    key            = "${var.tfstate_key_vpc}"
    region         = "${var.tfstate_region}"
    profile        = "${var.tfstate_profile}"
    role_arn       = "${var.tfstate_arn}"
  }
}

data "aws_security_groups" "elb" {
  tags = "${var.source_elb_sg_tags}"
}

resource aws_s3_bucket "log" {
  count  = "${var.logging_enabled && var.log_bucket_name == "" ? 1 : 0 }"
  bucket = "${local.name}-log"
  acl    = "private"
  tags   = "${merge(local.common_tags, var.tags)}"
}

data "aws_elb_service_account" "main" {}

data "aws_iam_policy_document" "s3_policy" {
  count  = "${var.logging_enabled && var.log_bucket_name == "" ? 1 : 0 }"
  statement = {
    actions = ["s3:PutObject"]
    resources = [
      "arn:aws:s3:::${local.log_bucket_name}${var.log_location_prefix}/*",
      "arn:aws:s3:::${local.log_bucket_name}${var.log_location_prefix}"
    ]

    principals = {
      identifiers = ["${data.aws_elb_service_account.main.arn}"]
      type = "AWS"
    }
  }
}

resource "aws_s3_bucket_policy" "s3_log" {
  count  = "${var.logging_enabled && var.log_bucket_name == "" ? 1 : 0 }"
  bucket = "${aws_s3_bucket.log.id}"
  policy = "${data.aws_iam_policy_document.s3_policy.json}"
}

data "aws_acm_certificate" "cert" {
  count       = "${var.https_listeners_count > 0 ? 1 : 0}"
  domain      = "${local.cert_domain}"
  statuses    = ["ISSUED"]
  most_recent = true
}

locals {
  common_name = "${var.namespace == "" ? "" : "${lower(var.namespace)}-"}${lower(var.project_env_short)}-${lower(var.name)}"
  name        = "${var.customized_name == "" ? local.common_name : var.customized_name}"
  common_tags = {
         Env  = "${var.project_env}"
         Name = "${local.name}"
  }

  cert_domain         = "${var.cert_domain == "" ? var.domain_name : var.cert_domain}"
  certificate_arn     = "${element(concat(data.aws_acm_certificate.cert.*.arn, list("")), 0)}"
  dynamic_subnets     = [ "${split(",", var.load_balancer_is_internal ? join(",", data.terraform_remote_state.vpc.private_subnets) : join(",", data.terraform_remote_state.vpc.public_subnets))}" ]
  subnets             = [ "${split(",", length(var.subnets) > 0 ? join(",", var.subnets) : join(",", local.dynamic_subnets) )}" ]
  security_groups     = "${data.aws_security_groups.elb.ids}"
  log_bucket_name     = "${var.logging_enabled && var.log_bucket_name == "" ? "${local.name}-log" : var.log_bucket_name }"
  log_location_prefix = "${var.log_bucket_name == "" ? var.log_location_prefix : local.name }"
  https_listeners     = "${list(map("certificate_arn", "${local.certificate_arn}", "port", "${var.https_port}"))}"
  http_tcp_listeners  = "${list(map("port", "${var.http_port}", "protocol", "HTTP"))}"
  target_groups_count = "${length(var.target_group_names)}"
}

resource "null_resource" "target_groups" {
  count = "${length(var.target_group_names)}"

  triggers {
    name                             = "${element(var.target_group_names,count.index)}"
    backend_protocol                 = "${var.backend_protocol}"
    backend_port                     = "${var.backend_port}"
    health_check_interval            = "${var.health_check_interval}"
    health_check_healthy_threshold   = "${var.health_check_healthy_threshold}"
    health_check_unhealthy_threshold = "${var.health_check_unhealthy_threshold}"
    health_check_path                = "${var.health_check_path}"
    health_check_matcher             = "${var.health_check_matcher}"
    stickiness_enabled               = "${var.stickiness_enabled}"
  }
}

////// Application Load balancer
module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "3.6.0"
  tags    = "${merge(var.tags,local.common_tags)}"
  
  load_balancer_name       = "${local.name}"
  security_groups          = "${local.security_groups}"
  logging_enabled          = "${var.logging_enabled}"
  log_bucket_name          = "${local.log_bucket_name}"
  log_location_prefix      = "${local.log_location_prefix}"
  subnets                  = "${local.subnets}"
  vpc_id                   = "${data.terraform_remote_state.vpc.vpc_id}"
  https_listeners          = "${local.https_listeners}"
  https_listeners_count    = "${var.https_listeners_count}"
  http_tcp_listeners       = "${local.http_tcp_listeners}"
  http_tcp_listeners_count = "1"
  target_groups            = "${null_resource.target_groups.*.triggers}"
  target_groups_count      = "${local.target_groups_count}"

  enable_http2                 = "${var.enable_http2}"
  ip_address_type              = "${var.ip_address_type}"
  idle_timeout                 = "${var.idle_timeout}"
  enable_deletion_protection   = "${var.enable_deletion_protection}"
  extra_ssl_certs_count        = "${var.extra_ssl_certs_count}"
  extra_ssl_certs              = "${var.extra_ssl_certs}"
  listener_ssl_policy_default  = "${var.listener_ssl_policy_default}"
  load_balancer_is_internal    = "${var.load_balancer_is_internal}"
  load_balancer_create_timeout = "${var.load_balancer_create_timeout}"
  load_balancer_delete_timeout = "${var.load_balancer_delete_timeout}"
  load_balancer_update_timeout = "${var.load_balancer_update_timeout}"
  enable_cross_zone_load_balancing = "${var.enable_cross_zone_load_balancing}"

}

////// Target Group Attachment
locals = {
  num_instance_tags = "${length(keys(var.instance_tags))}"
  instance_tags     = "${merge(var.instance_tags,map("Env","${var.project_env}"))}"
}

data "aws_instances" "ec2" {
  count         = "${local.num_instance_tags > 0 ? 1 : 0}"  
  instance_tags = "${local.instance_tags}"
}

locals = {
  ec2_instances = "${flatten(coalescelist(data.aws_instances.ec2.*.ids,list()))}"
}

resource "aws_lb_target_group_attachment" "ec2_http" {
  count            = "${local.num_instance_tags > 0 ? length(local.ec2_instances) : 0}"
  target_group_arn = "${module.alb.target_group_arns[0]}"
  target_id        = "${element(local.ec2_instances, count.index)}"
  port             = "${var.backend_port}"
}
