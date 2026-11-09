# push

Push notification plumbing: SNS FCM platform application (Firebase key), optional delivery-status logging, optional notification-service workload role (Pod Identity or IRSA), optional reminder SQS queues and EventBridge Scheduler, and CloudWatch alarms.

## Usage

```hcl
module "push" {
  source = "../../modules/push"
  # ... required inputs below
}
```

## Inputs

| Name | Description | Required |
|---|---|---|
| `name_prefix` | Prefix used for resource names. | no |
| `eks_cluster_name` | Name of an existing EKS cluster used to scope the workload role trust policy; required only when create_workload_role is true. | no |
| `create_workload_role` | Create the IAM role and policies that notification-service pods assume through Pod Identity or IRSA. | no |
| `firebase_service_account_json` | Firebase service-account JSON content used by SNS FCM HTTP v1. Supply securely, for example with TF_VAR_firebase_service_account_json. | yes |
| `alert_topic_arn` | SNS topic ARN for alarms. Leave empty to create alarms without notification actions. | no |
| `enable_reminder` | Create reminder SQS queues and EventBridge Scheduler resources and grant reminder permissions. | no |
| `enable_dlq_alarm` | Create an alarm for visible messages in the reminder dead-letter queue. | no |
| `identity_mode` | How the notification-service pod receives AWS credentials: EKS Pod Identity (default) or IRSA. | no |
| `eks_namespace` | Kubernetes namespace containing notification-service. | no |
| `eks_service_account` | Kubernetes service account used by notification-service. | no |
| `oidc_provider_arn` | EKS OIDC provider ARN   required when identity_mode is irsa. | no |
| `enable_delivery_logging` | Create the SNS delivery status logging role and attach it to the platform application. Needs iam:PassRole for the caller. | no |
| `delivery_success_sample_rate` | Percentage of successful deliveries SNS should log (0-100). | no |
| `publish_failure_threshold` | Failed SNS notifications per evaluation period that trigger the alarm. | no |
| `dlq_visible_messages_threshold` | Visible DLQ messages that trigger the reminder DLQ alarm. | no |
| `tags` | Tags applied to supported resources. | no |

## Outputs

| Name | Description |
|---|---|
| `platform_application_arn` | SNS FCM platform application ARN. |
| `notification_service_role_arn` | IAM role ARN for notification-service workload identity. |
| `reminder_queue_arn` | Reminder SQS queue ARN, when reminders are enabled. |
| `reminder_dlq_arn` | Reminder dead-letter queue ARN, when reminders are enabled. |
| `scheduler_group_name` | EventBridge Scheduler group name, when reminders are enabled. |
