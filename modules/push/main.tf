data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

locals {
  alarm_actions      = var.alert_topic_arn == "" ? [] : [var.alert_topic_arn]
  oidc_provider_path = var.oidc_provider_arn == "" ? "" : trimprefix(var.oidc_provider_arn, "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/")
}

resource "aws_iam_role" "sns_delivery_logging" {
  count = var.enable_delivery_logging ? 1 : 0
  name  = "${var.name_prefix}-sns-delivery-logging"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "sns.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy" "sns_delivery_logging" {
  count = var.enable_delivery_logging ? 1 : 0
  name  = "${var.name_prefix}-sns-delivery-logging"
  role  = aws_iam_role.sns_delivery_logging[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
      Resource = [
        "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:sns/${data.aws_region.current.name}/${data.aws_caller_identity.current.account_id}/*",
        "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:sns/${data.aws_region.current.name}/${data.aws_caller_identity.current.account_id}/*:log-stream:*"
      ]
    }]
  })
}

resource "aws_sns_platform_application" "push" {
  name                = "${var.name_prefix}-fcm"
  platform            = "GCM"
  platform_credential = var.firebase_service_account_json

  # Delivery status logging needs iam:PassRole for the caller; it is optional so a restricted user can still create the application.
  success_feedback_role_arn    = var.enable_delivery_logging ? aws_iam_role.sns_delivery_logging[0].arn : null
  failure_feedback_role_arn    = var.enable_delivery_logging ? aws_iam_role.sns_delivery_logging[0].arn : null
  success_feedback_sample_rate = var.enable_delivery_logging ? var.delivery_success_sample_rate : null
  depends_on                   = [aws_iam_role_policy.sns_delivery_logging]
}

resource "aws_iam_role" "notification_service" {
  count = var.create_workload_role ? 1 : 0
  name  = "${var.name_prefix}-notification-service"
  assume_role_policy = var.identity_mode == "pod_identity" ? jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "pods.eks.amazonaws.com"
      }
      Action = ["sts:AssumeRole", "sts:TagSession"]
      Condition = {
        StringEquals = {
          "aws:SourceAccount" = data.aws_caller_identity.current.account_id
        }
        ArnEquals = {
          "aws:SourceArn" = var.eks_cluster_arn
        }
      }
    }]
    }) : jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = var.oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_provider_path}:aud" = "sts.amazonaws.com"
          "${local.oidc_provider_path}:sub" = "system:serviceaccount:${var.eks_namespace}:${var.eks_service_account}"
        }
      }
    }]
  })
  tags = var.tags

  lifecycle {
    precondition {
      condition     = var.identity_mode != "irsa" || var.oidc_provider_arn != ""
      error_message = "oidc_provider_arn is required when identity_mode is irsa."
    }

    precondition {
      condition     = !var.create_workload_role || var.identity_mode != "pod_identity" || var.eks_cluster_arn != ""
      error_message = "eks_cluster_arn is required when create_workload_role is true and identity_mode is pod_identity."
    }
  }
}

resource "aws_iam_role_policy" "notification_service" {
  count = var.create_workload_role ? 1 : 0
  name  = "${var.name_prefix}-notification-service"
  role  = aws_iam_role.notification_service[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sns:CreatePlatformEndpoint",
          "sns:DeleteEndpoint",
          "sns:GetEndpointAttributes",
          "sns:Publish",
          "sns:SetEndpointAttributes"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = data.aws_region.current.name
          }
        }
      }
    ]
  })
}

# Reminder flow permissions are a separate policy so they only exist when the flow is enabled.
resource "aws_iam_role_policy" "notification_service_reminder" {
  count = var.create_workload_role && var.enable_reminder ? 1 : 0
  name  = "${var.name_prefix}-notification-service-reminder"
  role  = aws_iam_role.notification_service[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["sqs:SendMessage", "sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes", "sqs:GetQueueUrl"]
        Resource = aws_sqs_queue.reminder[0].arn
      },
      {
        Effect   = "Allow"
        Action   = ["scheduler:CreateSchedule", "scheduler:DeleteSchedule", "scheduler:GetSchedule", "scheduler:UpdateSchedule"]
        Resource = "arn:${data.aws_partition.current.partition}:scheduler:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:schedule/${aws_scheduler_schedule_group.reminder[0].name}/*"
      },
      {
        Effect   = "Allow"
        Action   = ["iam:PassRole"]
        Resource = aws_iam_role.scheduler_execution[0].arn
        Condition = {
          StringEquals = {
            "iam:PassedToService" = "scheduler.amazonaws.com"
          }
        }
      }
    ]
  })
}

resource "aws_cloudwatch_metric_alarm" "publish_failures" {
  alarm_name          = "${var.name_prefix}-sns-publish-failures"
  alarm_description   = "SNS delivery failures for the push platform application."
  namespace           = "AWS/SNS"
  metric_name         = "NumberOfNotificationsFailed"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = var.publish_failure_threshold
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  dimensions = {
    Application = aws_sns_platform_application.push.name
  }
  alarm_actions = local.alarm_actions
  tags          = var.tags
}

resource "aws_sqs_queue" "reminder_dlq" {
  count                     = var.enable_reminder ? 1 : 0
  name                      = "${var.name_prefix}-reminder-dlq"
  message_retention_seconds = 1209600
  tags                      = var.tags
}

resource "aws_sqs_queue" "reminder" {
  count                      = var.enable_reminder ? 1 : 0
  name                       = "${var.name_prefix}-reminder"
  visibility_timeout_seconds = 60
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.reminder_dlq[0].arn
    maxReceiveCount     = 5
  })
  tags = var.tags
}

resource "aws_scheduler_schedule_group" "reminder" {
  count = var.enable_reminder ? 1 : 0
  name  = "${var.name_prefix}-reminders"
  tags  = var.tags
}

resource "aws_iam_role" "scheduler_execution" {
  count = var.enable_reminder ? 1 : 0
  name  = "${var.name_prefix}-scheduler-execution"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "scheduler.amazonaws.com"
      }
      Action = "sts:AssumeRole"
      Condition = {
        StringEquals = {
          "aws:SourceAccount" = data.aws_caller_identity.current.account_id
        }
        ArnEquals = {
          "aws:SourceArn" = aws_scheduler_schedule_group.reminder[0].arn
        }
      }
    }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy" "scheduler_execution" {
  count = var.enable_reminder ? 1 : 0
  name  = "${var.name_prefix}-scheduler-send-reminder"
  role  = aws_iam_role.scheduler_execution[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["sqs:SendMessage"]
      Resource = aws_sqs_queue.reminder[0].arn
    }]
  })
}

resource "aws_cloudwatch_metric_alarm" "reminder_dlq_depth" {
  count               = var.enable_reminder && var.enable_dlq_alarm ? 1 : 0
  alarm_name          = "${var.name_prefix}-reminder-dlq-depth"
  alarm_description   = "Messages are visible in the reminder dead-letter queue."
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  statistic           = "Maximum"
  period              = 300
  evaluation_periods  = 1
  threshold           = var.dlq_visible_messages_threshold
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  dimensions = {
    QueueName = aws_sqs_queue.reminder_dlq[0].name
  }
  alarm_actions = local.alarm_actions
  tags          = var.tags
}
