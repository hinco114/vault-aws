variable "name" {
  type        = string
  description = "Project name used for EKS and VPC resources."
}

variable "region" {
  type        = string
  description = "AWS region for the stack."
}

variable "my_ip_cidr" {
  type        = string
  description = "Allowed CIDR for public cluster endpoint."
}
