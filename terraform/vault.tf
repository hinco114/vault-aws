# Helm Provider 를 설정합니다. (EKS 클러스터에 접근하기 위한 설정)
provider "helm" {
  kubernetes = {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
  }
}

# Helm Destroy 시 EKS 리소스가 삭제된 후 120초 동안 대기합니다. (연관 리소스가 잘 삭제되도록 하기 위함)
resource "terraform_data" "wait_after_helm_destroy" {
  input = "wait_after_helm_destroy"

  provisioner "local-exec" {  
    when    = destroy
    command = "sleep 120"
  }

  depends_on = [
    module.eks
  ]
}

# Vault Helm Chart 를 사용하여 Vault 를 설치합니다.
resource "helm_release" "vault" {
  name             = "vault"
  repository       = "https://helm.releases.hashicorp.com"
  chart            = "vault"
  namespace        = "vault"
  create_namespace = true

  # Vault Helm Chart 값을 설정합니다. (HA 모드 및 Raft 스토리지 활성화)
  values = [
    <<-EOF
    server:
      affinity: ""
      ha:
        enabled: true
        replicas: 3
        raft:
          enabled: true
          setNodeId: true
          config: |
            ui = true
            listener "tcp" {
              tls_disable = 1
              address = "[::]:8200"
              cluster_address = "[::]:8201"
            }
            storage "raft" {
              path = "/vault/data"
            }
    ui:
      enabled: true
      serviceType: LoadBalancer
      annotations:
        service.beta.kubernetes.io/aws-load-balancer-scheme: internet-facing
        service.beta.kubernetes.io/aws-load-balancer-type: external
    EOF
  ]

  depends_on = [
    terraform_data.wait_after_helm_destroy
  ]
}
