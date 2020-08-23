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

  #   attribute {
  #     name = "firstname"
  #     type = "S"
  #   }

  #   attribute {
  #     name = "lastname"
  #     type = "S"
  #   }

  #   attribute {
  #     name = "email"
  #     type = "S"
  #   }

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.this.arn
  }
}

resource "aws_lambda_function" "this" {
  filename         = "lambda.zip"
  function_name    = "func_customers"
  role             = aws_iam_role.lambda.arn
  handler          = "main.lambda_handler"
  source_code_hash = filebase64sha256("lambda.zip")
  runtime          = "python3.7"
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
                "dynamodb:PutItem"
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

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${aws_lambda_function.this.function_name}"
  retention_in_days = 14
}

resource "aws_api_gateway_rest_api" "this" {
  name = "${var.project}_api"
}

resource "aws_api_gateway_resource" "customers" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = "customers"
}

resource "aws_api_gateway_method" "customers" {
  rest_api_id      = aws_api_gateway_rest_api.this.id
  resource_id      = aws_api_gateway_resource.customers.id
  http_method      = "POST"
  authorization    = "NONE"
  api_key_required = true
}

# resource "aws_api_gateway_resource" "proxy" {
#   rest_api_id = aws_api_gateway_rest_api.this.id
#   parent_id   = aws_api_gateway_rest_api.this.root_resource_id
#   path_part   = "{proxy+}"
# }

# resource "aws_api_gateway_method" "proxy" {
#   rest_api_id      = aws_api_gateway_rest_api.this.id
#   resource_id      = aws_api_gateway_resource.proxy.id
#   http_method      = "ANY"
#   authorization    = "NONE"
# #   api_key_required = false
# }

resource "aws_api_gateway_integration" "lambda" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_method.customers.resource_id
  http_method = aws_api_gateway_method.customers.http_method
#   resource_id = aws_api_gateway_method.proxy.resource_id
#   http_method = aws_api_gateway_method.proxy.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.this.invoke_arn
}


resource "aws_api_gateway_deployment" "this" {
  depends_on = [
    aws_api_gateway_integration.lambda,
    aws_api_gateway_integration.lambda_root
  ]

  rest_api_id = aws_api_gateway_rest_api.this.id
  stage_name  = "test"
}

resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.this.execution_arn}/*/*"
}

resource "aws_api_gateway_api_key" "default" {
  name = "${var.project}_apikey"
}

resource "aws_api_gateway_method" "proxy_root" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_rest_api.this.root_resource_id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda_root" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_method.proxy_root.resource_id
  http_method = aws_api_gateway_method.proxy_root.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.this.invoke_arn
}

# resource "aws_api_gateway_resource" "proxy" {
#   rest_api_id = aws_api_gateway_rest_api.this.id
#   parent_id   = aws_api_gateway_rest_api.this.root_resource_id
#   path_part   = "{proxy+}"
# }

# resource "aws_api_gateway_method" "proxy" {
#   rest_api_id      = aws_api_gateway_rest_api.this.id
#   resource_id      = aws_api_gateway_resource.proxy.id
#   http_method      = "ANY"
#   authorization    = "NONE"
#   api_key_required = false
# }