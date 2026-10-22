data "aws_caller_identity" "current" {}

locals {
  account_id  = data.aws_caller_identity.current.account_id
  repo        = "${var.github_owner}/${var.github_repo}"
  oidc_host   = "token.actions.githubusercontent.com"
  cluster_arn = "arn:aws:eks:${var.region}:${local.account_id}:cluster/${var.eks_cluster_name}"

  oidc_provider_arn = (
    var.create_github_oidc_provider
    ? aws_iam_openid_connect_provider.github[0].arn
    : "arn:aws:iam::${local.account_id}:oidc-provider/${local.oidc_host}"
  )

  # Which GitHub job identity may assume which role
  gha_roles = {
    build      = "repo:${local.repo}:ref:refs/heads/main"
    staging    = "repo:${local.repo}:environment:staging"
    production = "repo:${local.repo}:environment:production"
  }
}

# ---------- GitHub OIDC provider ----------
resource "aws_iam_openid_connect_provider" "github" {
  count          = var.create_github_oidc_provider ? 1 : 0
  url            = "https://${local.oidc_host}"
  client_id_list = ["sts.amazonaws.com"]
}

# ---------- ECR repositories ----------
resource "aws_ecr_repository" "app" {
  for_each             = toset(var.apps)
  name                 = "cyb3r-${each.key}"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }
}

resource "aws_ecr_lifecycle_policy" "app" {
  for_each   = aws_ecr_repository.app
  repository = each.value.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep the last 20 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 20
      }
      action = { type = "expire" }
    }]
  })
}

# ---------- IAM roles for GitHub Actions ----------
data "aws_iam_policy_document" "gha_trust" {
  for_each = local.gha_roles

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:sub"
      values   = [each.value]
    }
  }
}

resource "aws_iam_role" "gha" {
  for_each             = local.gha_roles
  name                 = "cyb3r-gha-${each.key}"
  assume_role_policy   = data.aws_iam_policy_document.gha_trust[each.key].json
  max_session_duration = 3600
}

# Build role: push images to the two ECR repos only
data "aws_iam_policy_document" "build" {
  statement {
    sid       = "EcrLogin"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid = "PushAppImages"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage",
    ]
    resources = [for r in aws_ecr_repository.app : r.arn]
  }
}

resource "aws_iam_role_policy" "build" {
  name   = "cyb3r-ecr-push"
  role   = aws_iam_role.gha["build"].id
  policy = data.aws_iam_policy_document.build.json
}

# Deploy roles: find the cluster; Kubernetes rights come from EKS access entries
data "aws_iam_policy_document" "deploy" {
  statement {
    sid       = "FindCluster"
    actions   = ["eks:DescribeCluster"]
    resources = [local.cluster_arn]
  }
}

resource "aws_iam_role_policy" "deploy" {
  for_each = toset(["staging", "production"])
  name     = "cyb3r-eks-describe"
  role     = aws_iam_role.gha[each.key].id
  policy   = data.aws_iam_policy_document.deploy.json
}