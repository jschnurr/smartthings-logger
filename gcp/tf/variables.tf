variable "postfix" {
  description = "Random id to ensure uniqueness of resource names."
  type        = string
}

variable "project_name" {
  description = "The project name in GCP. Env will be appended automatically."
  type        = string
}

variable "region" {
  description = "The region for the GCP project."
  type        = string
}

variable "billing_account" {
  description = "The billing account for the GCP project."
  type        = string
}

variable "owner_email" {
  description = "The email address of the owner of the GCP project."
  type        = string
}
