terraform {
  required_version = "= 0.12.19"

  backend "remote" {
    hostname     = "app.terraform.io"
    organization = "<my organization>"
    workspaces {
      name = "<my workspace>"
    }
  }
}

provider "aws" {
  region = "us-west-2"
}

variable "project_name" {}
variable "cron_schedule" {}
variable "lambda_timeout_sec" {}
variable "lambda_memory_mb" {}

resource "aws_s3_bucket" "cloud-cron" {
  bucket_prefix = var.project_name
  acl           = "private"
  force_destroy = true
}

resource "aws_lambda_function" "cloud-cron" {
  function_name    = var.project_name
  role             = aws_iam_role.lambda-assume.arn
  handler          = "index.lambda"
  runtime          = "nodejs12.x"
  timeout          = var.lambda_timeout_sec
  memory_size      = var.lambda_memory_mb
  s3_bucket        = aws_s3_bucket.cloud-cron.id
  s3_key           = "code/master/lambda.zip"

  environment {
    variables = {
      NODE_ENV = "production"
    }
  }

  depends_on    = [aws_iam_role_policy_attachment.allow_logging, aws_cloudwatch_log_group.cloud-cron]
}

resource "aws_iam_role" "lambda-assume" {
  name = "${var.project_name}_lambda_assume"

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

resource "aws_cloudwatch_log_group" "cloud-cron" {
  name              = "/aws/lambda/${var.project_name}"
  retention_in_days = 14
}

resource "aws_iam_policy" "allow_logging" {
  name = "${var.project_name}_allow_logging"
  path = "/"
  description = "IAM policy to allow writing logs"

  policy = <<EOF
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
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "allow_logging" {
  role = aws_iam_role.lambda-assume.name
  policy_arn = aws_iam_policy.allow_logging.arn
}

resource "aws_iam_policy" "allow_put_to_bucket" {
  name = "allow_put_to_${aws_s3_bucket.cloud-cron.id}_bucket"
  path = "/"
  description = "IAM policy to allow put object permissions in the ${aws_s3_bucket.cloud-cron.id} bucket"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:putObject"
      ],
      "Resource": "${aws_s3_bucket.cloud-cron.arn}/data/*",
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "allow_lambda_put_data" {
  role = aws_iam_role.lambda-assume.name
  policy_arn = aws_iam_policy.allow_put_to_bucket.arn
}

resource "aws_cloudwatch_event_rule" "cron-schedule" {
  name                = var.project_name
  description         = "run the ${var.project_name} lambda function on a schedule"
  schedule_expression = var.cron_schedule
  is_enabled          = true
}

resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cloud-cron.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.cron-schedule.arn
}

resource "aws_cloudwatch_event_target" "cron_target_lambda" {
  rule = aws_cloudwatch_event_rule.cron-schedule.name
  arn  = aws_lambda_function.cloud-cron.arn
}

resource "aws_iam_access_key" "ci" {
  user = aws_iam_user.ci.name
}

resource "aws_iam_user" "ci" {
  name = "${var.project_name}_ci"
  path = "/"
}

data "aws_iam_policy_document" "ci" {
  statement {
    actions   = ["s3:putObject"]
    effect    = "Allow"
    resources = ["${aws_s3_bucket.cloud-cron.arn}/code/*"]
  }
}

resource "aws_iam_user_policy" "ci" {
  name   = "${var.project_name}_ci"
  user   = aws_iam_user.ci.name
  policy = data.aws_iam_policy_document.ci.json
}
