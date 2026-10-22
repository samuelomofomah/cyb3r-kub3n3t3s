# cyb3r-kub3n3t3s

Enterprise multi-app delivery: Terraform-built platform, Jenkins CI/CD with Snyk scans,
k3s staging, approval gate, and Amazon EKS (us-east-1) production.

## v2 pipeline
GitHub Actions: tests → Snyk (deps, IaC, image) → ECR → EKS staging → manual approval → EKS production.
AWS access uses GitHub OIDC with immutable subjects; no long-lived credentials.

Production deploys require approval via the GitHub production environment.
