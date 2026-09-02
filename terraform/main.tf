locals {
  module_source_base = "github.com/AyaanK1/terraform-module-library"
}

module "vpc" {
  source = "${local.module_source_base}//modules/vpc"

  name       = "${var.project_name}-${var.environment}"
  cidr_block = var.vpc_cidr
  azs        = var.azs

  public_subnet_cidrs  = [for i in range(length(var.azs)) : cidrsubnet(var.vpc_cidr, 4, i)]
  private_subnet_cidrs = [for i in range(length(var.azs)) : cidrsubnet(var.vpc_cidr, 4, i + length(var.azs))]

  single_nat_gateway = var.environment == "dev"

  tags = { Environment = var.environment, Project = var.project_name }
}

module "eks" {
  source = "${local.module_source_base}//modules/eks"

  cluster_name       = var.project_name
  kubernetes_version = var.cluster_version
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.private_subnet_ids

  node_instance_types = var.node_instance_types
  node_desired_size   = var.node_desired_size
  node_min_size       = var.node_min_size
  node_max_size       = var.node_max_size

  # Only true for quick demo/testing - keep false for anything real
  endpoint_public_access = var.environment == "dev"

  tags = { Environment = var.environment, Project = var.project_name }
}

module "ecr" {
  source = "${local.module_source_base}//modules/ecr"

  repository_name = var.ecr_repository_name
  tags            = { Environment = var.environment, Project = var.project_name }
}

# App-tier security group, scoped to accept traffic only from within the VPC
# rather than from any CIDR on the internet.
module "app_security_group" {
  source = "${local.module_source_base}//modules/security-group"

  name   = "${var.project_name}-app-sg"
  vpc_id = module.vpc.vpc_id

  ingress_rules = [{
    description = "App port from within the VPC only"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }]

  tags = { Environment = var.environment, Project = var.project_name }
}

# Dedicated namespace so the app is isolated from kube-system / other workloads
resource "kubernetes_namespace" "app" {
  metadata {
    name = "microservice-app"
  }

  depends_on = [module.eks]
}

# Deploy the app via the local Helm chart once the cluster and namespace exist
resource "helm_release" "app" {
  name      = "microservice-app"
  chart     = "${path.module}/../helm/app"
  namespace = kubernetes_namespace.app.metadata[0].name

  set {
    name  = "image.repository"
    value = module.ecr.repository_url
  }

  set {
    name  = "image.tag"
    value = "latest"
  }

  depends_on = [kubernetes_namespace.app]
}
