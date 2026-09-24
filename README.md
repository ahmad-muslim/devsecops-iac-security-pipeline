# DevSecOps IaC Security Pipeline

An automated Infrastructure-as-Code (IaC) security scanning pipeline using **Terraform**, **Checkov**, and **GitHub Actions**.

This repository demonstrates how to integrate automated security guardrails into a CI/CD workflow to detect and remediate cloud infrastructure misconfigurations before deployment.

---

## Architecture Diagram

```mermaid
flowchart TD
    A[Local Developer<br/>Terraform Code] -->|1. Git Push / PR| B[GitHub Repository<br/>Main Branch]
    B -->|2. Trigger Workflow| C[GitHub Actions Runner]
    C -->|3. Execute Checkov| D[Checkov Static Analysis]
    
    D --> E[Infrastructure Scan<br/>main.tf]
    D --> F[Pipeline Scan<br/>checkov.yml]
    
    E --> G{Evaluates Guardrails}
    F --> G
    
    G -->|Failures Detected| H[Exit Code 1<br/>Build Failed / Blocked]
    G -->|All Passed| I[Exit Code 0<br/>Build Passed / Safe]

---

## Sample Failure Output

When security violations are detected during a local Docker scan or a GitHub Actions execution, Checkov outputs detailed findings and returns `failure;status=1`.

```plain
terraform scan results:

Passed checks: 20, Failed checks: 7, Skipped checks: 0

Check: CKV_AWS_7: "Ensure rotation for customer created CMKs is enabled"
        FAILED for resource: aws_kms_key.s3_key
        File: /main.tf:29-32

Check: CKV2_AWS_64: "Ensure KMS key Policy is defined"
        FAILED for resource: aws_kms_key.s3_key
        File: /main.tf:29-32

Check: CKV2_AWS_5: "Ensure that Security Groups are attached to another resource"
        FAILED for resource: aws_security_group.dev_sg
        File: /main.tf:69-81

Check: CKV_AWS_18: "Ensure the S3 bucket has access logging enabled"
        FAILED for resource: aws_s3_bucket.dev_bucket

Check: CKV2_AWS_61: "Ensure that an S3 bucket has a lifecycle configuration"
        FAILED for resource: aws_s3_bucket.dev_bucket

Check: CKV2_AWS_62: "Ensure S3 buckets should have event notifications enabled"
        FAILED for resource: aws_s3_bucket.dev_bucket

Check: CKV_AWS_144: "Ensure that S3 bucket has cross-region replication enabled"
        FAILED for resource: aws_s3_bucket.dev_bucket

github_actions scan results:
Passed checks: 16, Failed checks: 0, Skipped checks: 0

failure;status=1

## Remediation Sample
Below is the remediated main.tf configuration addressing core security requirements:
```
Terraform
data "aws_caller_identity" "current" {}

# KMS Key for S3 Bucket Encryption
resource "aws_kms_key" "s3_key" {
  description             = "KMS key for S3 bucket encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true # Fixes CKV_AWS_7

  # Fixes CKV2_AWS_64: Explicit key policy
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      }
    ]
  })
}

# S3 Bucket Configuration
resource "aws_s3_bucket" "dev_bucket" {
  bucket = "devsecops-test-bucket"

  # Inline skips for non-production development environments
  #checkov:skip=CKV_AWS_144:Cross-region replication not required for dev environment
  #checkov:skip=CKV2_AWS_62:Event notifications not needed for dev testing
  #checkov:skip=CKV_AWS_18:Access logging omitted for local environment
  #checkov:skip=CKV2_AWS_61:Lifecycle configuration omitted for dev environment
}

# Block S3 Public Access
resource "aws_s3_bucket_public_access_block" "dev_bucket_pab" {
  bucket                  = aws_s3_bucket.dev_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 Versioning Configuration
resource "aws_s3_bucket_versioning" "dev_bucket_versioning" {
  bucket = aws_s3_bucket.dev_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 Default Server-Side Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "dev_bucket_encryption" {
  bucket = aws_s3_bucket.dev_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.s3_key.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

# Security Group Configuration
resource "aws_security_group" "dev_sg" {
  name        = "dev-server-sg"
  description = "Security group for local development testing"

  ingress {
    description = "Allow internal HTTP access"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }
}
```
## Local Usage & Testing
To execute Checkov locally using Docker prior to pushing code:

Bash
docker run --rm -v "$(pwd):/tf" bridgecrew/checkov -d /tf
