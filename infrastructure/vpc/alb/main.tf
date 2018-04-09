/**
 * The ALB module creates an ALB, security group
 * a route53 record and a service healthcheck.
 * It is used by the service module.
 */

variable "name" {
  description = "ALB name, e.g cdn"
}

variable "subnet_ids" {
  description = "A list of subnet IDs"
  type        = "list"
  default     = ["subnet-2368b468", "subnet-819a27f8", "subnet-21e6747b"]
}

variable "environment" {
  description = "Environment tag, e.g prod"
}

variable "port" {
  description = "Instance port"
}

variable "security_groups" {
  description = "A list of SG IDs"
  type        = "list"
  default     = ["sg-82903bfc"]
}

variable "dns_name" {
  description = "Route53 record name"
}

variable "healthcheck" {
  description = "Healthcheck path"
}

variable "protocol" {
  description = "Protocol to use, HTTP or TCP"
}

variable "zone_id" {
  description = "Route53 zone ID to use for dns_name"
}

variable "subdomain" {
  description = "subdomain name"
}

variable "log_bucket" {
  description = "S3 bucket name to write ELB logs into"
}

variable "listener_port" {
  description = "The Port that the listener will use, usually one of 80, 443."
}

variable "listener_protocol" {
  description = "The protocol of the listen, ususally one of HTTP, HTTPS or TCP."
}

variable "ssl_certificate_id" {
  description = "For HTTPS we need to specify the SSL Certificate (ARN) to use."
}

variable "vpc_id" {
  description = "The id of the VPC the ALB should be associated with."
}

/**
 * Optional
 */

variable "use_sticky_sessions" {
  description = "Whether the ALB should use sticky sessions."
  default     = false
}

/**
 * Resources.
 */

resource "aws_alb" "main" {
  name            = "${var.name}"
  internal        = false
  subnets         = ["${split(",",var.subnet_ids)}"]
  security_groups = ["${split(",",var.security_groups)}"]

  access_logs {
    bucket = "${var.log_bucket}"
  }
}

resource "aws_alb_target_group" "main" {
  name       = "alb-target-${var.name}"
  port       = "${var.port}"
  protocol   = "HTTP"
  vpc_id     = "${var.vpc_id}"
  depends_on = ["aws_alb.main"]

  stickiness {
    type    = "lb_cookie"
    enabled = "${var.use_sticky_sessions}"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    protocol            = "HTTP"
    path                = "${var.healthcheck}"
    interval            = 30
  }
}

resource "aws_alb_listener" "main_listener" {
  load_balancer_arn = "${aws_alb.main.arn}"
  port              = "${var.listener_port}"
  protocol          = "${var.listener_protocol}"
  ssl_policy        = "${var.listener_protocol == "HTTPS" ? "ELBSecurityPolicy-2016-08" : ""}"
  certificate_arn   = "${var.listener_protocol == "HTTPS" ? var.ssl_certificate_id : ""}"

  default_action {
    target_group_arn = "${aws_alb_target_group.main.arn}"
    type             = "forward"
  }
}

resource "aws_route53_record" "subdomain" {
  zone_id = "${var.zone_id}"
  name    = "${var.subdomain}"
  type    = "A"

  alias {
    zone_id                = "${aws_alb.main.zone_id}"
    name                   = "${aws_alb.main.dns_name}"
    evaluate_target_health = false
  }
}

/**
 * Module Output
 */

output "name" {
  value = "${aws_alb.main.name}"
}

output "id" {
  value = "${aws_alb.main.id}"
}

output "dns" {
  value = "${aws_alb.main.dns_name}"
}

output "fqdn" {
  value = "${aws_route53_record.subdomain.fqdn}"
}

// The zone id of the ALB
output "zone_id" {
  value = "${aws_alb.main.zone_id}"
}

output "target_group" {
  value = "${aws_alb_target_group.main.arn}"
}
