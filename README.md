# DevSecOps IaC Security Pipeline

An automated Infrastructure-as-Code (IaC) security scanning pipeline using **Terraform**, **Checkov**, and **GitHub Actions**.

This repository demonstrates how to integrate automated security guardrails into a CI/CD workflow to detect and remediate cloud infrastructure misconfigurations before deployment.

---

## Architecture Diagram

+------------------+         +-------------------+         +-----------------------+
| Local Developer  |         | GitHub Repository |         | GitHub Actions CI/CD  |
|  (Terraform Code)|         |   (Main Branch)   |         |   (Runner Environment)|
+--------+---------+         +---------+---------+         +-----------+-----------+
|                             |                               |
| 1. Git Push / PR            |                               |
+---------------------------->+                               |
| 2. Trigger Workflow                                         |
+------------------------------------------------------------>+
|
| 3. Execute Checkov Scan
v
+-----------------------+
|   Checkov Static      |
|   Code Analysis       |
+-----------+-----------+
|
+-------------------------+-------------------------+
|                                                   |
v                                                   v
[ Infrastructure Scan ]                             [ Pipeline Scan ]
main.tf                                   checkov.yml
|                                                   |
+-------------------------+-------------------------+
|
v
+-----------------------+
| Evaluates Guardrails  |
+-----------+-----------+
|
+------------------+------------------+
|                                     |
(Failures Detected)                     (All Passed)
|                                     |
v                                     v
+--------------------------+          +--------------------------+
| Exit Code 1 (Build Fail) |          | Exit Code 0 (Build Pass) |
| Block Deployment         |          | Safe to Provision        |
+--------------------------+          +--------------------------+


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
