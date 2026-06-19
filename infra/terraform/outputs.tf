output "lambda_function_name" {
  description = "Name of the Lambda function for processing uploads"
  value       = aws_lambda_function.process_uploaded_file.function_name
}
output "s3_upload_bucket_name" {
  description = "Name of the S3 bucket for file uploads"
  value       = aws_s3_bucket.upload_bucket.bucket
}
output "frontend_bucket_name" {
  description = "Name of the S3 bucket hosting the frontend"
  value       = aws_s3_bucket.frontend_bucket.bucket
}
output "cloudfront_url" {
  description = "CloudFront distribution domain name"
  value       = aws_cloudfront_distribution.frontend_distribution.domain_name
}
output "presigned_url_api_endpoint" {
  description = "API Gateway endpoint for generating presigned URLs"
  value       = aws_api_gatewayv2_api.my_api.api_endpoint
}