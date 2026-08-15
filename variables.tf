variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name prefix used for tagging resources"
  type        = string
  default     = "ecommerce-demo-tf"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "Availability zones to use"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "coupan_port" {
  description = "Port coupan-app listens on"
  type        = number
  default     = 8081
}

variable "product_port" {
  description = "Port product-app listens on"
  type        = number
  default     = 8082
}

variable "coupan_image" {
  description = "Docker image for coupan-app"
  type        = string
  default     = "himeshsithum/coupan_app_new"
}

variable "product_image" {
  description = "Docker image for product-app"
  type        = string
  default     = "himeshsithum/product_app_new"
}

variable "db_name" {
  description = "Default database name"
  type        = string
  default     = "productcoupandb"
}

variable "db_username" {
  description = "Master username for RDS"
  type        = string
  default     = "root"
}

variable "db_password" {
  description = "Master password for RDS"
  type        = string
  sensitive   = true
}

variable "service_connect_namespace" {
  description = "Cloud Map namespace name for ECS Service Connect"
  type        = string
  default     = "ecommerce-demo-tf"
}

variable "task_cpu" {
  description = "Fargate task CPU units"
  type        = string
  default     = "512"
}

variable "task_memory" {
  description = "Fargate task memory (MB)"
  type        = string
  default     = "1024"
}
