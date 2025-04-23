/**
 * Environnement de développement
 */

provider "aws" {
  region = var.aws_region
}

# Configuration du backend Terraform pour l'état distant
terraform {
  backend "s3" {
    bucket         = "example-terraform-state"
    key            = "dev/terraform.tfstate"
    region         = "us-west-2"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}

# Données AWS
data "aws_availability_zones" "available" {}

# Module VPC
module "vpc" {
  source = "../../modules/vpc"

  cidr_block         = var.vpc_cidr
  environment        = var.environment
  availability_zones = slice(data.aws_availability_zones.available.names, 0, 2)
  enable_nat_gateway = true

  tags = var.tags
}

# Module ECS
module "ecs" {
  source = "../../modules/ecs"

  environment        = var.environment
  vpc_id             = module.vpc.vpc_id
  public_subnet_ids  = module.vpc.public_subnet_ids
  private_subnet_ids = module.vpc.private_subnet_ids
  
  container_image    = var.container_image
  container_port     = var.container_port
  task_cpu           = var.task_cpu
  task_memory        = var.task_memory
  desired_count      = var.desired_count
  min_capacity       = var.min_capacity
  max_capacity       = var.max_capacity
  
  health_check_path         = var.health_check_path
  logs_retention_days       = var.logs_retention_days
  enable_container_insights = var.enable_container_insights
  
  certificate_arn      = var.certificate_arn
  aws_region           = var.aws_region
  container_environment = var.container_environment
  container_secrets    = var.container_secrets

  tags = var.tags
}

# Ressources supplémentaires pour l'environnement de développement
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.environment}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            [ "AWS/ECS", "CPUUtilization", "ClusterName", module.ecs.cluster_name, "ServiceName", module.ecs.service_name ]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "ECS CPU Utilization"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            [ "AWS/ECS", "MemoryUtilization", "ClusterName", module.ecs.cluster_name, "ServiceName", module.ecs.service_name ]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "ECS Memory Utilization"
        }
      }
    ]
  })
}