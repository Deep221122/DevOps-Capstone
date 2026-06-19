terraform {
  required_version = ">= 1.5.0"

# Remote Backend
    backend "s3" {
        bucket = "devops-accelerator-platform-tf-state-1906"
        key = "global/devops-accelerator/terraform.tfstste"
        region = "us-east-1"
        dynamodb_table = "devops-accelerator-tf-locker" #locking
        encrypt = true
  }
}

provider "aws" {
    region = var.aws_region
}

# -----------------------------
# Frontend Hosting (S3 + CloudFront)
# -----------------------------
resource "aws_s3_bucket" "frontend_bucket" {
  bucket        = var.frontend_bucket_name
  force_destroy = true

  tags = {
    Name = "Frontend Hosting Bucket"
  }
}

# Disable Block Public Access so bucket policy works
resource "aws_s3_bucket_public_access_block" "frontend_bucket_public_access" {
  bucket = aws_s3_bucket.frontend_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# Static website hosting
resource "aws_s3_bucket_website_configuration" "frontend_bucket_website" {
  bucket = aws_s3_bucket.frontend_bucket.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

# Public bucket policy (depends on disabling Block Public Access first)
resource "aws_s3_bucket_policy" "frontend_bucket_policy" {
  bucket = aws_s3_bucket.frontend_bucket.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "PublicReadGetObject",
        Effect    = "Allow",
        Principal = "*",
        Action    = "s3:GetObject",
        Resource  = "${aws_s3_bucket.frontend_bucket.arn}/*"
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.frontend_bucket_public_access]
}

# CORS (optional, for presigned uploads / APIs)
resource "aws_s3_bucket_cors_configuration" "frontend_cors" {
  bucket = aws_s3_bucket.frontend_bucket.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "PUT", "HEAD"]
    allowed_origins = ["https://${aws_cloudfront_distribution.frontend_distribution.domain_name}"]
    expose_headers  = []
    max_age_seconds = 3000
  }
}