terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region                      = "us-east-1"
  access_key                  = "mock_key"
  secret_key                  = "mock_secret"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  s3_use_path_style           = true

  endpoints {
    s3  = "http://localhost:4566"
    ec2 = "http://localhost:4566"
    kms = "http://localhost:4566"
  }
}

# KMS Key for S3 Encryption
resource "aws_kms_key" "s3_key" {
  description             = "KMS key for S3 bucket encryption"
  deletion_window_in_days = 7
}

# S3 Bucket
resource "aws_s3_bucket" "dev_bucket" {
  bucket = "devsecops-test-bucket"
}

# Fix CKV2_AWS_6: Block Public Access
resource "aws_s3_bucket_public_access_block" "dev_bucket_pab" {
  bucket                  = aws_s3_bucket.dev_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Fix CKV_AWS_21: Enable Versioning
resource "aws_s3_bucket_versioning" "dev_bucket_versioning" {
  bucket = aws_s3_bucket.dev_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Fix CKV_AWS_145: KMS Encryption by Default
resource "aws_s3_bucket_server_side_encryption_configuration" "dev_bucket_encryption" {
  bucket = aws_s3_bucket.dev_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.s3_key.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

# Security Group
resource "aws_security_group" "dev_sg" {
  name        = "dev-server-sg"
  description = "Security group for local development testing"

  # Fix CKV_AWS_23: Description on ingress rule & restrict cidr block
  ingress {
    description = "Allow HTTP access internally"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"] # Restricted internal range instead of 0.0.0.0/0
  }
}
