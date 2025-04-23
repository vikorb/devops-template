variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "us-west-2"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "container_image" {
  description = "Docker image to run"
  type        = string
  default     = "nginx:latest"  # Image par défaut pour le développement
}

variable "container_port" {
  description = "Port exposed by the container"
  type        = number
  default     = 80
}

variable "task_cpu" {
  description = "CPU units for the task"
  type        = number
  default     = 256  # 0.25 vCPU
}

variable "task_memory" {
  description = "Memory for the task in MiB"
  type        = number
  default     = 512
}

variable "desired_count" {
  description = "Number of instances of the task to run"
  type        = number
  default     = 1  # Une seule instance en développement
}

variable "min_capacity" {
  description = "Minimum number of tasks"
  type        = number
  default     = 1
}

variable "max_capacity" {
  description = "Maximum number of tasks"
  type        = number
  default     = 2
}

variable "health_check_path" {
  description = "Path for ALB health checks"
  type        = string
  default     = "/"
}

variable "logs_retention_days" {
  description = "CloudWatch Logs retention period"
  type        = number
  default     = 7  # Rétention plus courte en développement
}

variable "enable_container_insights" {
  description = "Whether to enable container insights for the cluster"
  type        = bool
  default     = true
}

variable "certificate_arn" {
  description = "ARN of the SSL certificate for HTTPS"
  type        = string
  default     = "arn:aws:acm:us-west-2:123456789012:certificate/example"  # Remplacer par un ARN valide
}

variable "container_environment" {
  description = "Environment variables for the container"
  type        = list(object({
    name  = string
    value = string
  }))
  default     = [
    {
      name  = "NODE_ENV"
      value = "development"
    },
    {
      name  = "LOG_LEVEL"
      value = "debug"
    }
  ]
}

variable "container_secrets" {
  description = "Secrets for the container from SSM Parameter Store or Secrets Manager"
  type        = list(object({
    name