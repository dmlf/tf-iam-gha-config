output "created_roles" {
  description = "List of created IAM roles"
  value       = aws_iam_role.role[*]
}

output "oidc_provider_arn" {
  description = "ARN of the AWS IAM OpenID Connect Provider"
  value       = data.aws_iam_openid_connect_provider.oidc_provider.arn
}