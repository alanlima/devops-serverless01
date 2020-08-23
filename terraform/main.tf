resource "aws_ssm_parameter" "db_name" {
  name  = "DB_NAME"
  type  = "String"
  value = var.db_name
  tags  = var.common_tags
}

resource "aws_ssm_parameter" "api_key" {
  name  = "API_KEY"
  type  = "String"
  value = "initial-key"
  tags  = var.common_tags
}