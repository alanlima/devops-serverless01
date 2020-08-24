resource "aws_ssm_parameter" "db_name" {
  name  = "/${var.project}/DB_NAME"
  type  = "String"
  value = var.db_name
  tags  = var.common_tags
}

resource "aws_ssm_parameter" "api_key" {
  name  = "/${var.project}/API_KEY"
  type  = "SecureString"
  value = aws_api_gateway_api_key.default.value
  tags  = var.common_tags
}

resource "aws_kms_key" "this" {
  description             = "${var.project} - DB Encrypt Key"
  deletion_window_in_days = 7
  tags                    = var.common_tags
}

resource "aws_dynamodb_table" "this" {
  name           = var.db_name
  billing_mode   = "PROVISIONED"
  write_capacity = 5
  read_capacity  = 5
  hash_key       = "id"

  attribute {
    name = "id"
    type = "S"
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.this.arn
  }

  tags  = var.common_tags
}

resource "aws_lambda_function" "this" {
  filename         = "lambda.zip"
  function_name    = "func_customers"
  role             = aws_iam_role.lambda.arn
  handler          = "main.lambda_handler"
  source_code_hash = filebase64sha256("lambda.zip")
  runtime          = "python3.8"
  tags  = var.common_tags
  environment {
    variables = {
      DB_NAME = aws_ssm_parameter.db_name.value
    }
  }
  depends_on = [
    aws_iam_role_policy_attachment.lambda
  ]
}

resource "aws_iam_role" "lambda" {
  name = "${var.project}_lambda_role"
tags  = var.common_tags
  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
                "Service": "lambda.amazonaws.com"
            },
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
EOF
}

resource "aws_iam_policy" "lambda" {
  name        = "${var.project}_lambda_policy"
  path        = "/"
  description = "IAM policy for logging from a lambda function"
  policy      = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": "arn:aws:logs:*:*:*",
            "Effect": "Allow"
        },
        {
            "Action": [
                "dynamodb:PutItem",
                "dynamodb:Scan"
            ],
            "Resource": "${aws_dynamodb_table.this.arn}",
            "Effect": "Allow"
        },
        {
            "Action": [
                "kms:Decrypt"
            ],
            "Resource": "arn:aws:kms:*",
            "Effect": "Allow"
        }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "lambda" {
  role       = aws_iam_role.lambda.name
  policy_arn = aws_iam_policy.lambda.arn
}