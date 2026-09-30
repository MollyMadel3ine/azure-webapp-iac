variable "enable_app_gateway" {
  description = "Deploy the App Gateway (WAF_v2 bills roughly $0.45/hour while it exists). Also locks the app to the private-endpoint-only access."
  type        = bool
  default     = false
}
