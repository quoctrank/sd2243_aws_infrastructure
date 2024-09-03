provider "aws" {
  region = local.region
}
 
locals {
  name   = "sd2243-aws"
  region = "ap-southeast-1"
 
  vpc_cidr = "10.0.0.0/16"
  azs      = ["ap-southeast-1a", "ap-southeast-1b"]
 
  enable_nat_gateway = true
  enable_vpn_gateway = true
 
  tags = {
    Name       = local.name
    Example    = local.name
  }
}
 
################################################################################
# VPC Module
################################################################################
 
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  name = "${local.name}-vpc"
  cidr = local.vpc_cidr
  azs             = local.azs
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 4, k)]
  tags = local.tags
}
 
################################################################################
# EC2 Module
################################################################################
 
module "ec2-instance" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  name = "${local.name}-ec2"
 
  instance_type          = "t2.micro"
  key_name               = "sd2243-aws-key-pair"
  monitoring             = true
  vpc_security_group_ids = [module.security_group.security_group_id]
  subnet_id              = element(module.vpc.private_subnets, 0)
 
  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}
 
module "security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"
 
  name        = "${local.name}-security_group"
  description = "Security group for example usage with EC2 instance"
  vpc_id      = module.vpc.vpc_id
 
  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["http-80-tcp", "all-icmp"]
  egress_rules        = ["all-all"]
 
  tags = local.tags
}
 
################################################################################
# ECR Module
################################################################################
 
module "ecr_frontend" {
  source = "terraform-aws-modules/ecr/aws"
 
  repository_name = "${local.name}-frontend_repo"
 
  repository_read_write_access_arns = ["arn:aws:iam::767xxxxx:user/quoctrank"]
  repository_lifecycle_policy = jsonencode({
    rules = [
      {
        rulePriority = 1,
        description  = "Keep last 30 images",
        selection = {
          tagStatus     = "tagged",
          tagPrefixList = ["v"],
          countType     = "imageCountMoreThan",
          countNumber   = 30
        },
        action = {
          type = "expire"
        }
      }
    ]
  })
 
  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}
 
module "ecr_backend" {
  source = "terraform-aws-modules/ecr/aws"
 
  repository_name = "${local.name}-backend_repo"
 
  repository_read_write_access_arns = ["arn:aws:iam::767xxxxx:user/quoctrank"]
  repository_lifecycle_policy = jsonencode({
    rules = [
      {
        rulePriority = 1,
        description  = "Keep last 30 images",
        selection = {
          tagStatus     = "tagged",
          tagPrefixList = ["v"],
          countType     = "imageCountMoreThan",
          countNumber   = 30
        },
        action = {
          type = "expire"
        }
      }
    ]
  })
 
  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}
 
################################################################################
# EKS Module
################################################################################
 
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"
 
  cluster_name    = "${local.name}-cluster"
  cluster_version = "1.30"
 
  cluster_endpoint_public_access  = true
 
  cluster_addons = {
    coredns                = {}
    eks-pod-identity-agent = {}
    kube-proxy             = {}
    vpc-cni                = {}
  }
 
  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
 
  # EKS Managed Node Group(s)
  eks_managed_node_group_defaults = {
    ami_type = "AL2023_x86_64_STANDARD"
  }
 
  eks_managed_node_groups = {
    general = {
      # Starting on 1.30, AL2023 is the default AMI type for EKS managed node groups
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = ["t2.micro"]
 
      min_size     = 2
      max_size     = 10
      desired_size = 2
    }
  }
}