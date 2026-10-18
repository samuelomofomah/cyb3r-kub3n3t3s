# ---------- Lookups ----------
data "aws_caller_identity" "current" {}

data "http" "my_ip" {
  url = "https://checkip.amazonaws.com"
}

locals {
  my_ip_cidr    = "${chomp(data.http.my_ip.response_body)}/32"
  ingress_ports = { ssh = 22, staging_web = 80, jenkins = 8080 }
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical, the publisher of Ubuntu

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnet" "platform" {
  vpc_id            = data.aws_vpc.default.id
  availability_zone = "${var.region}a"
  default_for_az    = true
}

# ---------- SSH key ----------
resource "tls_private_key" "ssh" {
  algorithm = "ED25519"
}

resource "aws_key_pair" "platform" {
  key_name   = "${var.name}-key"
  public_key = tls_private_key.ssh.public_key_openssh
}

resource "local_sensitive_file" "pem" {
  content         = tls_private_key.ssh.private_key_openssh
  filename        = "${path.module}/${var.name}.pem"
  file_permission = "0400"
}

# ---------- Firewall ----------
resource "aws_security_group" "platform" {
  name        = "${var.name}-sg"
  description = "cyb3r-kub3n3t3s platform server"
  vpc_id      = data.aws_vpc.default.id
}

resource "aws_vpc_security_group_ingress_rule" "from_my_ip" {
  for_each          = local.ingress_ports
  security_group_id = aws_security_group.platform.id
  cidr_ipv4         = local.my_ip_cidr
  from_port         = each.value
  to_port           = each.value
  ip_protocol       = "tcp"
  description       = each.key
}

resource "aws_vpc_security_group_egress_rule" "all_out" {
  security_group_id = aws_security_group.platform.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "Allow all outbound (apt, Docker Hub, GitHub, Snyk, AWS APIs)"
}

# ---------- IAM role for Jenkins (replaces manual Step 3B.1) ----------
data "aws_iam_policy_document" "ec2_trust" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "jenkins_platform" {
  name               = "cyb3r-jenkins-platform-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_trust.json
}

data "aws_iam_policy_document" "describe_prod_cluster" {
  statement {
    sid       = "ReadProdClusterInfo"
    actions   = ["eks:DescribeCluster"]
    resources = ["arn:aws:eks:${var.region}:${data.aws_caller_identity.current.account_id}:cluster/${var.eks_cluster_name}"]
  }
}

resource "aws_iam_role_policy" "describe_prod_cluster" {
  name   = "cyb3r-describe-prod-cluster"
  role   = aws_iam_role.jenkins_platform.id
  policy = data.aws_iam_policy_document.describe_prod_cluster.json
}

resource "aws_iam_instance_profile" "jenkins_platform" {
  name = "cyb3r-jenkins-platform-profile"
  role = aws_iam_role.jenkins_platform.name
}

# ---------- The server ----------
resource "aws_instance" "platform" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = data.aws_subnet.platform.id
  key_name               = aws_key_pair.platform.key_name
  vpc_security_group_ids = [aws_security_group.platform.id]
  iam_instance_profile   = aws_iam_instance_profile.jenkins_platform.name

  root_block_device {
    volume_size = var.root_volume_gb
    volume_type = "gp3"
    encrypted   = true
  }

  metadata_options {
    http_tokens                 = "required" # IMDSv2 only
    http_put_response_hop_limit = 2
  }

  tags = {
    Name = var.name
  }
}

# ---------- A public IP that never changes ----------
resource "aws_eip" "platform" {
  instance = aws_instance.platform.id
  domain   = "vpc"

  tags = {
    Name = "${var.name}-eip"
  }
}