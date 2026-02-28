# VPC 모듈을 사용하여 VPC 를 생성합니다.
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.6.0"

  name = "${var.name}-vpc"
  cidr = "10.1.0.0/16"

  azs             = ["${var.region}a", "${var.region}b", "${var.region}c"]
  private_subnets = ["10.1.1.0/24", "10.1.2.0/24", "10.1.3.0/24"]
  public_subnets  = ["10.1.101.0/24", "10.1.102.0/24", "10.1.103.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }
}

# EKS 클러스터를 생성합니다.
module "eks_cluster" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = var.name
  kubernetes_version = "1.35"

  # EKS 클러스터 엔드포인트에 외부에서 접근 가능하도록 설정 (현재 접속한 IP만 허용)
  endpoint_public_access       = true
  endpoint_public_access_cidrs = [var.my_ip_cidr]

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # EKS Auto mode 설정
  compute_config = {
    enabled    = true
    node_pools = ["general-purpose"]
  }

  # 테라폼을 실행하는 IAM 사용자/역할에 클러스터 관리자 권한 부여
  enable_cluster_creator_admin_permissions = true
}

# Kubernetes Provider 를 설정합니다. (EKS 클러스터에 접근하기 위한 설정)
provider "kubernetes" {
  host                   = module.eks_cluster.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks_cluster.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks_cluster.cluster_name]
  }
}

# StorageClass 를 생성합니다. (EBS CSI 프로비저너 사용, Vault HA 모드에서 필요)
resource "kubernetes_storage_class_v1" "gp3" {
  depends_on = [module.eks_cluster]

  metadata {
    name = "gp3"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }

  # EKS Auto Mode 는 아래의 관리형 EBS CSI 프로비저너를 사용.
  storage_provisioner    = "ebs.csi.eks.amazonaws.com"
  allow_volume_expansion = true
  reclaim_policy         = "Delete"
  volume_binding_mode    = "WaitForFirstConsumer"

  parameters = {
    type      = "gp3"
    fsType    = "ext4"
    encrypted = "true"
  }
}
