# 개요
이 Repository 는 [HashiCorp Vault](https://developer.hashicorp.com/vault) 를 AWS 환경에서 사용하는 예제를 담고 있습니다.  
Terraform 코드로 인프라를 생성한 뒤, [vault-example](./vault-example/) 경로에 있는 Jupyter Notebook 예제로 실행해볼 수 있습니다.  
필요한 변수는 환경변수를 주로 사용하므로, [direnv](https://direnv.net/) 를 활용하거나 직접 환경 변수를 세팅해주세요.  
K8s 관련 사용법은 [VSO(Vault Secrets Operator)](https://developer.hashicorp.com/vault/docs/deploy/kubernetes/vso) 를 기준으로만 설명합니다.  

# 검증 실행 환경
- OS: Mac
- [Terraform](https://developer.hashicorp.com/terraform) : 1.5.7
- [AWS CLI](https://docs.aws.amazon.com/ko_kr/cli/latest/userguide/cli-chap-getting-started.html) : 2.33.4
- [Python](https://www.python.org/) : 3.9.6
- [direnv](https://direnv.net/) : 2.37.1
- [kubectl](https://kubernetes.io/ko/docs/reference/kubectl/) : 1.35.0
- [Docker Desktop](https://docs.docker.com/desktop/) : 4.63.0

# 따라하기 팁
## VSCode 계열 IDE 사용시
- IDE 에서 [Jupyter Extension](https://marketplace.visualstudio.com/items?itemName=ms-toolsai.jupyter) 설치
- [install_notebook_bash_kernel.sh](./vault-example/install_notebook_bash_kernel.sh) 로 venv 환경의 Jupyter Notebook 구성
- Jupyter Notebbok 에서 Bash Kernel 선택 후 Notebook 예제 수행


# 인프라 구성시 유용한 링크들
- Vault Install in EKS : https://developer.hashicorp.com/vault/tutorials/kubernetes-platforms/kubernetes-amazon-eks
- Vault Helm Chart : https://artifacthub.io/packages/helm/hashicorp/vault
- Vault Helm Configuration : https://developer.hashicorp.com/vault/docs/deploy/kubernetes/helm/configuration
- Vault AWS KMS Seal : https://developer.hashicorp.com/vault/docs/configuration/seal/awskms

# Vault 사용에 유용한 링크들
- Vault KV Engine : https://developer.hashicorp.com/vault/docs/secrets/kv
- Vault AWS Engine : https://developer.hashicorp.com/vault/docs/secrets/aws
- Vault K8s Auth : https://developer.hashicorp.com/vault/docs/auth/kubernetes
- Vault IAM Auth : https://developer.hashicorp.com/vault/docs/auth/aws
- VSO(Vault Secerts Operator) : https://developer.hashicorp.com/vault/docs/deploy/kubernetes/vso