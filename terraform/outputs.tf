output "lambda" {
  value = aws_lambda_function.this
}

output "api" {
  value = aws_api_gateway_rest_api.this
}

output "zbase_url" {
  value = aws_api_gateway_deployment.this.invoke_url
}

output "apikey" {
  value = aws_api_gateway_api_key.default
}