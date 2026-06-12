###############################################################################
# infra/terraform/main.tf
# Minimal AWS infra for Kamal deployment:
#   VPC → EC2 (t3.micro) → Elastic IP → Security Group
#   No ALB, no RDS — Kamal/Traefik handles routing, PG runs as Docker sidecar
###############################################################################

terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Store state in S3 — bootstrap bucket manually or with:
  # aws s3 mb s3://tfstate-<project>-<env> --region us-east-1
  backend "s3" {
    bucket  = "tfstate-ruby-api"
    key     = "infra/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Project   = var.project
      Env       = var.environment
      ManagedBy = "Terraform"
    }
  }
}

###############################################################################
# VARIABLES
###############################################################################

variable "aws_region" { default = "us-east-1" }
variable "project" { default = "ruby-api" }
variable "environment" { default = "production" }
variable "instance_type" { default = "t3.micro" } # ~$8.5/mo — upgrade to t3.small if needed
variable "ssh_public_key" { description = "EC2 SSH public key content" }
variable "allowed_ssh_cidr" {
  description = "CIDRs allowed SSH access (restrict to your IP!)"
  default     = "0.0.0.0/0" # Change to YOUR_IP/32 in production
}
variable "ebs_volume_size" { default = 20 } # GB — holds OS + Docker + PG data
variable "ami_id" { default = "" }          # leave blank for latest Ubuntu 22.04

###############################################################################
# DATA
###############################################################################

data "aws_availability_zones" "available" { state = "available" }

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

locals {
  ami = var.ami_id != "" ? var.ami_id : data.aws_ami.ubuntu.id
  az  = data.aws_availability_zones.available.names[0]
}

###############################################################################
# NETWORKING
###############################################################################

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/24" # /24 is plenty for a single-server setup
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags                 = { Name = "${var.project}-vpc" }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.project}-igw" }
}

resource "aws_subnet" "main" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = local.az
  map_public_ip_on_launch = false # We use Elastic IP instead
  tags                    = { Name = "${var.project}-subnet" }
}

resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = { Name = "${var.project}-rt" }
}

resource "aws_route_table_association" "main" {
  subnet_id      = aws_subnet.main.id
  route_table_id = aws_route_table.main.id
}

###############################################################################
# SECURITY GROUP — least-privilege
###############################################################################

resource "aws_security_group" "app" {
  name        = "${var.project}-sg"
  description = "Ruby API server -HTTP/HTTPS/SSH only"
  vpc_id      = aws_vpc.main.id

  # HTTP — Traefik will redirect to HTTPS
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS — main traffic
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # # SSH — Kamal deploys over SSH; restrict to your IP in prod!
  # ingress {
  #   description = "SSH (Kamal deploy)"
  #   from_port   = 22
  #   to_port     = 22
  #   protocol    = "tcp"
  #   cidr_blocks = [var.allowed_ssh_cidr]
  # }

  # All outbound (Docker pulls, Let's Encrypt, package updates)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project}-sg" }
}

###############################################################################
# IAM — SSM Session Manager (SSH-less access as backup)
###############################################################################

resource "aws_iam_role" "ec2" {
  name = "${var.project}-deploy-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${var.project}-profile"
  role = aws_iam_role.ec2.name
}

###############################################################################
# KEY PAIR
###############################################################################

resource "aws_key_pair" "deploy" {
  key_name   = "${var.project}-deploy-key"
  public_key = var.ssh_public_key
}

###############################################################################
# EC2 INSTANCE — single t3.micro, everything in Docker
###############################################################################

resource "aws_instance" "app" {
  ami                    = local.ami
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.main.id
  vpc_security_group_ids = [aws_security_group.app.id]
  key_name               = aws_key_pair.deploy.key_name
  iam_instance_profile   = aws_iam_instance_profile.ec2.name

  # Enforce IMDSv2 (prevents SSRF metadata attacks)
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_size           = var.ebs_volume_size
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
    tags                  = { Name = "${var.project}-root-vol" }
  }

  # Cloud-init: install Docker + Kamal dependencies
  user_data = base64encode(<<-USERDATA
    #!/bin/bash
    set -euo pipefail
    exec > /var/log/user-data.log 2>&1

    # Update and install Docker
    apt-get update -qq
    apt-get install -y --no-install-recommends \
      ca-certificates curl gnupg lsb-release git unzip

    # Docker official repo
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
      gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.gpg] \
      https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
      > /etc/apt/sources.list.d/docker.list

    apt-get update -qq
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

    # Enable and start Docker
    systemctl enable --now docker

    # Allow ubuntu user to run Docker (Kamal SSH user)
    usermod -aG docker ubuntu

    # Create data directory for Postgres volume
    mkdir -p /var/app/data/db
    chown -R ubuntu:ubuntu /var/app

    echo "Bootstrap complete — Docker $(docker --version)"
  USERDATA
  )

  tags = { Name = "${var.project}-server", Kamal = true }

  lifecycle {
    # Don't recreate if AMI updates — handle AMI updates manually
    ignore_changes = [ami, user_data]
  }
}

###############################################################################
# ELASTIC IP — stable IP across stop/start cycles
###############################################################################

resource "aws_eip" "app" {
  instance   = aws_instance.app.id
  domain     = "vpc"
  tags       = { Name = "${var.project}-eip" }
  depends_on = [aws_internet_gateway.main]
}

###############################################################################
# OUTPUTS
###############################################################################

output "server_ip" {
  description = "Elastic IP — set as DEPLOY_HOST GitHub secret"
  value       = aws_eip.app.public_ip
}

output "server_dns" {
  description = "Public DNS of EC2 instance"
  value       = aws_instance.app.public_dns
}

output "ssh_command" {
  description = "SSH into the server"
  value       = "ssh ubuntu@${aws_eip.app.public_ip}"
}

output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.app.id
}
