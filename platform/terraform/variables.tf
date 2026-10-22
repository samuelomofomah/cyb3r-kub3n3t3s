variable "region" {
  description = "AWS region for everything in this project"
  type        = string
  default     = "us-east-1"
}

variable "github_owner" {
  description = "GitHub user or org that owns the repo"
  type        = string
  default     = "samuelomofomah"
}

variable "github_repo" {
  description = "Repository allowed to assume the pipeline roles"
  type        = string
  default     = "cyb3r-kub3n3t3s"
}

variable "eks_cluster_name" {
  description = "EKS cluster hosting the staging and production namespaces"
  type        = string
  default     = "cyb3r-eks"
}

variable "apps" {
  description = "Services that get an ECR repository"
  type        = list(string)
  default     = ["api", "web"]
}

variable "create_github_oidc_provider" {
  description = "Set to false if the account already has the GitHub OIDC provider"
  type        = bool
  default     = true
}

variable "github_owner_id" {
  description = "Numeric GitHub account ID (used in immutable OIDC subjects)"
  type        = string
  default     = "254310021"
}

variable "github_repo_id" {
  description = "Numeric GitHub repository ID (used in immutable OIDC subjects)"
  type        = string
  default     = "1424661786"
}
