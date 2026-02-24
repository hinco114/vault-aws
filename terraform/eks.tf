locals {
  name   = "vault-aws"
  region = "ap-northeast-2"
}

provider "aws" {
  region = local.region
  default_tags {
    tags = {
      Project     = local.name
      Environment = "dev"
      Terraform   = "true"
    }
  }
}

data "http" "my_ip" {
  url = "https://ifconfig.me/ip"
}

locals {
  my_ip_cidr = "${chomp(data.http.my_ip.response_body)}/32"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.6.0"

  name = "${local.name}-vpc"
  cidr = "10.1.0.0/16"

  azs             = ["${local.region}a", "${local.region}b", "${local.region}c"]
  private_subnets = ["10.1.1.0/24", "10.1.2.0/24", "10.1.3.0/24"]
  public_subnets  = ["10.1.101.0/24", "10.1.102.0/24", "10.1.103.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  # 외부 로드밸런서를 위한 퍼블릭 서브넷 태그
  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  # 내부 로드밸런서를 위한 프라이빗 서브넷 태그
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = local.name
  kubernetes_version = "1.35"

  endpoint_public_access       = true
  endpoint_public_access_cidrs = [local.my_ip_cidr]

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

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

resource "kubernetes_storage_class_v1" "gp3" {
  depends_on = [module.eks]

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
