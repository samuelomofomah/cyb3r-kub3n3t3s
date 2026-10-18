variable "region" {
  description = "AWS region for everything in this project"
  type        = string
  default     = "us-east-1"
}

variable "name" {
  description = "Name of the platform server"
  type        = string
  default     = "cyb3r-kub3n3t3s-platform"
}

variable "instance_type" {
  description = "Free-tier eligible, 2 vCPU / 8 GiB, x86"
  type        = string
  default     = "m7i-flex.large"
}

variable "root_volume_gb" {
  description = "Disk size for Docker images and Jenkins builds"
  type        = number
  default     = 30
}

variable "eks_cluster_name" {
  description = "Production EKS cluster Jenkins is allowed to look up"
  type        = string
  default     = "cyb3r-prod"
}