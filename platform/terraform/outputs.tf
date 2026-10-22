output "account_id" {
  value = local.account_id
}

output "ecr_registry" {
  description = "Use as the image registry in the workflow"
  value       = "${local.account_id}.dkr.ecr.${var.region}.amazonaws.com"
}

output "role_arns" {
  value = { for k, r in aws_iam_role.gha : k => r.arn }
}