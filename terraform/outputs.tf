output "lambda_invoke_arn" {
  value = aws_lambda_function.this.invoke_arn
}

# output "api" {
#   value = aws_api_gateway_rest_api.this
# }

output "api_url" {
  value = aws_api_gateway_deployment.prod.invoke_url
}

output "api_key" {
  value = aws_api_gateway_api_key.default.value
}

output "report_topic_arn" {
  value = aws_sns_topic.report_count.arn
}

# output "photos_loc_file" {
#   value = data.archive_file.photos_handler
# }