variable "instance_type" {
  type    = string
  default = "n5.large"
}

variable "asg_size" {
  type    = number
  default = 4
}

variable "cidr_block" {
  type    = string
  default = "10.0.0.0/16"
}

variable "name_prefix" {
  type    = string
  default = "QuorumCluster"
}

variable "az_count" {
  type    = number
  default = 2
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "aws_profile" {
  type    = string
  default = "default"
}

terraform {
  required_version = ">= 0.12.0"
}

provider "aws" {
  profile = var.aws_profile
  region  = var.region
}

provider "random" {
  version = "~> 2.1"
}

provider "local" {
  version = "~> 1.2"
}

provider "null" {
  version = "~> 2.1"
}

data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_id
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token
  load_config_file       = false
  version                = "~> 1.11"
}

data "aws_availability_zones" "available" {
}

resource "random_string" "suffix" {
  length  = 8
  special = false
}

locals {
  cluster_name = "${var.name_prefix}-${random_string.suffix.result}"
}

resource "aws_security_group" "worker_group_mgmt_one" {
  name   = "worker_group_mgmt_one"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.cidr_block]
  }
}

locals {
  subnets         = [for num in range(var.az_count * 2) : cidrsubnet(var.cidr_block, 8, num)]
  private_subnets = slice(local.subnets, 0, var.az_count)
  public_subnets  = slice(local.subnets, var.az_count, var.az_count * 2)
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "2.6.0"

  name                 = var.name_prefix
  cidr                 = var.cidr_block
  azs                  = slice(data.aws_availability_zones.available.names, 0, var.az_count)
  private_subnets      = local.private_subnets
  public_subnets       = local.public_subnets
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  public_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                      = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"             = "1"
  }
}

module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  cluster_name    = local.cluster_name
  cluster_version = "1.16"
  subnets         = module.vpc.private_subnets
  vpc_id          = module.vpc.vpc_id
  worker_groups = [
    {
      name                          = "worker-group-1"
      instance_type                 = var.instance_type
      asg_max_size                  = var.asg_size
      asg_desired_capacity          = var.asg_size
      additional_security_group_ids = [aws_security_group.worker_group_mgmt_one.id]
    }
  ]
}

resource "null_resource" "update_kubeconfig" {
  provisioner "local-exec" {
    command = <<-EOD
        aws --profile ${var.aws_profile} eks \
            update-kubeconfig --name ${local.cluster_name}
    EOD
  }

  depends_on = [
    module.eks
  ]
}

resource "null_resource" "git_clone" {
  provisioner "local-exec" {
    command = <<-EOD
        mkdir downloads && git clone \
            https://github.com/jpmorganchase/qubernetes.git downloads/qubernetes
    EOD
  }

  depends_on = [
    module.eks,
    null_resource.update_kubeconfig
  ]
}

resource "null_resource" "run_qubernetes" {
  provisioner "local-exec" {
    command = <<-EOD
        kubectl apply -f \
            downloads/qubernetes/7nodes/istanbul-7nodes-tessera/k8s-yaml-pvc
    EOD
  }

  provisioner "local-exec" {
    when    = destroy
    command = "rm -rf downloads"
  }

  depends_on = [
    module.eks,
    null_resource.update_kubeconfig,
    null_resource.git_clone
  ]
}
