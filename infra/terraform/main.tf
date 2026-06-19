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

# CloudFront Distribution
resource "aws_cloudfront_distribution" "frontend_distribution" {
  enabled             = true
  default_root_object = "index.html"
  price_class         = var.cloudfront_price_class

  origin {
    domain_name = aws_s3_bucket_website_configuration.frontend_bucket_website.website_endpoint
    origin_id   = "S3-Frontend-Origin"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-Frontend-Origin"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = {
    Name = "FrontendCDN"
  }

  depends_on = [aws_s3_bucket_policy.frontend_bucket_policy]
}

# -----------------------------
# BACKEND DEPLOYMENT
# -----------------------------

# Create Lambda Execution Role 
resource "aws_iam_role" "lambda_exec_role" {
  name = "lambda_exec_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}
# Give AWS Lambda Execution Permission to this Role
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole" 
#   inbuilt lambda exec role policy
}
# Attach S3 Bucket Permission to This Role
resource "aws_iam_role_policy_attachment" "s3_access" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
#   giving S3 bucket access permission
}

# -----------------------------
# Upload Bucket
# -----------------------------

resource "aws_s3_bucket" "upload_bucket" {
  bucket        = var.upload_bucket_name
  force_destroy = true
}

# -----------------------------
# Lambda: Process Uploaded File
# -----------------------------

resource "aws_lambda_function" "process_uploaded_file" {
  function_name = "process-uploaded-file"
  runtime       = "python3.11"
  handler       = "main.lambda_handler"
  filename      = "${path.module}/../../backend/process-uploaded-file/lambda.zip"
  source_code_hash = filebase64sha256("${path.module}/../../backend/process-uploaded-file/lambda.zip")
  role = aws_iam_role.lambda_exec_role.arn

  environment {
    variables = {
      UPLOAD_BUCKET = aws_s3_bucket.upload_bucket.bucket
      SNS_TOPIC_ARN = aws_sns_topic.devops_accelerator_upload_notify.arn
    }
  }
}

# Notification Configuration for S3 bucket
# someting happens to s3 trigger lambda
resource "aws_s3_bucket_notification" "lambda_trigger" {
  bucket = aws_s3_bucket.upload_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.process_uploaded_file.arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_permission.allow_s3]
}
# allow lambda function to upload file on S3 Upload bucket
resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowExecutionFromS3"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.process_uploaded_file.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.upload_bucket.arn
}

# -----------------------------
# SNS Topic for Notifications
# -----------------------------

resource "aws_sns_topic" "devops_accelerator_upload_notify" {
  name = "devops-accelerator-upload-notification-topic"
}

resource "aws_sns_topic_subscription" "devops_accelerator_email_sub" {
  topic_arn = aws_sns_topic.devops_accelerator_upload_notify.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

resource "aws_iam_policy" "devops_accelerator_lambda_sns_policy" {
  name = "devops-accelerator-lambda-sns-publish-policy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = "sns:Publish",
        Resource = aws_sns_topic.devops_accelerator_upload_notify.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_sns_policy_attachment" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = aws_iam_policy.devops_accelerator_lambda_sns_policy.arn
}