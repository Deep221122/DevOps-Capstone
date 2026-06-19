variable "aws_region" {
    type = string
    description = "AWS Region to deploy resources"
    default = "us-east-1"
}
variable "upload_bucket_name" {
    description = "Name of s3 bucket to upload files"
    type = string
}
variable "frontend_bucket_name" {
    description = "Name of s3 bucket to host frontend"
    type = string
}
variable "cloudfront_price_class" {
    description = "CloudFront price class"
    type = string
    default = "PriceClass_100"
}
variable "notification_email" {
    description = "Email address for CloudFront notifications"
    type = string
}
