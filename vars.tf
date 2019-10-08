variable "project_env" { default = "Production" }
variable "project_env_short" { default = "prd" }

variable "aws_region" { default = "us-west-2" }
variable "aws_profile" { default = "default" }

variable "tfstate_bucket" { default = "example-tfstate-bucket" }
variable "tfstate_region" { default = "us-west-2" }
variable "tfstate_profile" { default = "default" }
variable "tfstate_arn" { default = "" }
variable "tfstate_key_vpc" { default = "demo/vpc/terraform.tfstate" }

variable "source_elb_sg_tags" { default = { Type = "ALB" } }
variable "instance_tags" { default = { Type = "WebApp" } }
variable "tags" { default = {} }

variable "domain_name" { default = "example.com" }
variable "cert_domain" { default = "" }

variable "namespace" { default = "" }
variable "name" { default = "alb" }
variable "customized_name" { default = "" }

variable "https_port" { default = "443" }
variable "http_port" { default = "80" }
variable "target_group_names" { default = ["webapp"] }

variable "backend_protocol" { default = "HTTP" } # HTTP, TCP
variable "backend_port" { default = "80" }
variable "health_check_interval" { default = "10" }
variable "health_check_healthy_threshold" { default = "2" }
variable "health_check_unhealthy_threshold" { default = "2" }
variable "health_check_path" { default = "/" }
variable "health_check_matcher" { default = "200-209" }
variable "stickiness_enabled" { default = false }

## Vars from the [terraform module](https://github.com/terraform-aws-modules/terraform-aws-alb/blob/v3.6.0/variables.tf)
variable "create_alb" {
  description = "Controls if the ALB should be created"
  default     = true
}

variable "enable_deletion_protection" {
  description = "If true, deletion of the load balancer will be disabled via the AWS API. This will prevent Terraform from deleting the load balancer. Defaults to false."
  default     = false
}

variable "enable_http2" {
  description = "Indicates whether HTTP/2 is enabled in application load balancers."
  default     = true
}

variable "enable_cross_zone_load_balancing" {
  description = "Indicates whether cross zone load balancing should be enabled in application load balancers."
  default     = false
}

variable "extra_ssl_certs" {
  description = "A list of maps describing any extra SSL certificates to apply to the HTTPS listeners. Required key/values: certificate_arn, https_listener_index (the index of the listener within https_listeners which the cert applies toward)."
  type        = "list"
  default     = []
}

variable "extra_ssl_certs_count" {
  description = "A manually provided count/length of the extra_ssl_certs list of maps since the list cannot be computed."
  default     = 0
}

variable "https_listeners_count" {
  description = "A manually provided count/length of the https_listeners list of maps since the list cannot be computed."
  default     = 1
}

variable "idle_timeout" {
  description = "The time in seconds that the connection is allowed to be idle."
  default     = 60
}

variable "ip_address_type" {
  description = "The type of IP addresses used by the subnets for your load balancer. The possible values are ipv4 and dualstack."
  default     = "ipv4"
}

variable "listener_ssl_policy_default" {
  description = "The security policy if using HTTPS externally on the load balancer. [See](https://docs.aws.amazon.com/elasticloadbalancing/latest/classic/elb-security-policy-table.html)."
  default     = "ELBSecurityPolicy-2016-08"
}

variable "load_balancer_is_internal" {
  description = "Boolean determining if the load balancer is internal or externally facing."
  default     = false
}

variable "load_balancer_create_timeout" {
  description = "Timeout value when creating the ALB."
  default     = "10m"
}

variable "load_balancer_delete_timeout" {
  description = "Timeout value when deleting the ALB."
  default     = "10m"
}

variable "load_balancer_update_timeout" {
  description = "Timeout value when updating the ALB."
  default     = "10m"
}

variable "logging_enabled" {
  description = "Controls if the ALB will log requests to S3."
  default     = true
}

variable "log_bucket_name" {
  description = "S3 bucket (externally created) for storing load balancer access logs. Required if logging_enabled is true."
  default     = ""
}

variable "log_location_prefix" {
  description = "S3 prefix within the log_bucket_name under which logs are stored."
  default     = ""
}

variable "subnets" {
  description = "A list of subnets to associate with the load balancer. e.g. ['subnet-1a2b3c4d','subnet-1a2b3c4e','subnet-1a2b3c4f']"
  type        = "list"
  default     = []
}
