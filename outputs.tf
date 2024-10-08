output "created_roles" {
  description = "List of created IAM roles"
  value       = aws_iam_role.role[*]
}