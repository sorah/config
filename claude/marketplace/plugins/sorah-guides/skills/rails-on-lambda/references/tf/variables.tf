variable "name" {
  type = string
}
variable "environment" {
  type = string
}
variable "app_domain" {
  type = string
}
variable "certificate_arn" {
  type = string
}
variable "initial_image_uri" {
  type = string
}

variable "environments" {
  type    = map(string)
  default = {}
}
variable "secrets" {
  type        = map(string)
  default     = {}
  description = "Environment variable name to SSM parameter ARN"
}
