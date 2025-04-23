/**
 * Configuration pour le stockage d'état Terraform distant
 * Ce module crée un bucket S3 et une table DynamoDB pour stocker l'état Terraform
 */

provider "aws" {
  region = var.aws_region
}

resource "aws_s3_bucket" "terraform_state" {
  bucket = var.terraform_state_bucket_name

  lifecycle {
    prevent_destroy = true
  }

  tags = var.tags
}

resource "aws_s3_bucket_versioning" "enabled" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "default" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "public_access" {
  bucket                  = aws_s3_bucket.terraform_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_dynamodb_table" "terraform_locks" {
  name         = var.terraform_locks_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = var.tags
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

variable "terraform_state_bucket_name" {
  description = "Name of the S3 bucket for Terraform state"
  type        = string
  default     = "example-terraform-state"
}

variable "terraform_locks_table_name" {
  description = "Name of the DynamoDB table for Terraform locks"
  type        = string
  default     = "terraform-locks"
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {
    Project   = "DevOpsTemplate"
    ManagedBy = "Terraform"
  }
}

output "s3_bucket_id" {
  value       = aws_s3_bucket.terraform_state.id
  description = "ID of the S3 bucket for Terraform state"
}

output "dynamodb_table_name" {
  value       = aws_dynamodb_table.terraform_locks.name
  description = "Name of the DynamoDB table for Terraform locks"
}