variable "slack_webhook_url" {
  description = "Slack incoming webhook URL for the #DevOps-Alerts channel."
  type        = string
  sensitive   = true
  default     = "https://hooks.slack.com/services/REPLACE/ME"
}
