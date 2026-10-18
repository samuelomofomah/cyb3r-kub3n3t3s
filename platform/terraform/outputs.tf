output "public_ip" {
  value = aws_eip.platform.public_ip
}

output "ssh_command" {
  value = "ssh -i ${local_sensitive_file.pem.filename} ubuntu@${aws_eip.platform.public_ip}"
}

output "jenkins_url" {
  value = "http://${aws_eip.platform.public_ip}:8080"
}

output "base_domain" {
  description = "Paste into BASE_DOMAIN in the Jenkinsfile"
  value       = "${aws_eip.platform.public_ip}.nip.io"
}

output "staging_url" {
  value = "http://staging.${aws_eip.platform.public_ip}.nip.io"
}

output "account_id" {
  value = data.aws_caller_identity.current.account_id
}

output "jenkins_role_arn" {
  value = aws_iam_role.jenkins_platform.arn
}