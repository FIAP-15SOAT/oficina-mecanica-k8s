<div align="center">

# ☸️ Oficina Mecânica — Plataforma Kubernetes e Contêineres (IaC)

**Provisionamento e configuração do cluster EKS, Node Group, ECR e recursos de plataforma Kubernetes com Terraform e Helm para a solução Oficina Mecânica.**

![Terraform](https://img.shields.io/badge/Terraform-%3E%3D1.11.0-844FBA?logo=terraform&logoColor=white)
![Kubernetes](https://img.shields.io/badge/Kubernetes-1.35-326CE5?logo=kubernetes&logoColor=white)
![AWS EKS](https://img.shields.io/badge/AWS-EKS-FF9900?logo=amazon-eks&logoColor=white)
![AWS ECR](https://img.shields.io/badge/AWS-ECR-FF9900?logo=amazon-aws&logoColor=white)
![Helm](https://img.shields.io/badge/Helm-3-0F1689?logo=helm&logoColor=white)

</div>

## 📋 Sobre

Este repositório contém o código de **Infraestrutura como Código (IaC)** responsável pelo provisionamento do cluster **Amazon EKS**, **Managed Node Group**, **Amazon ECR** (registro de imagens de contêiner) e da camada de plataforma dentro do Kubernetes para a solução **Oficina Mecânica**.

Faz parte do ecossistema de microsserviços e infraestrutura da pós-graduação em Arquitetura de Software da FIAP (turma 15SOAT, Fase 2).

### 🏗️ Recursos Provisionados

1. **Amazon EKS & Nós Gerenciados (`eks.tf`)**:
   - Cluster Kubernetes gerenciado na versão **1.35** com endpoints público e privado ativados.
   - Logs de auditoria e control plane centralizados no **CloudWatch Logs** (`/aws/eks/eks-oficina-mecanica/cluster`) com retenção de 14 dias.
   - Security Group dedicado para o control plane liberando comunicação HTTPS (porta 443) a partir da VPC.
   - **Managed Node Group** com instâncias `t3.small` distribuídas nas subnets privadas da VPC.

2. **Amazon ECR (`ecr.tf`)**:
   - Repositório de imagens de contêiner (`ecr-oficina-mecanica-app-repo`) com scan de vulnerabilidades automático no push e criptografia AES-256.
   - Política de ciclo de vida (*Lifecycle Policy*) configurada para manter as últimas 20 imagens, otimizando custos de armazenamento.

3. **Namespace Compartilhado (`k8s_namespace.tf`)**:
   - Criação do namespace `oficina`, isolando todos os recursos da aplicação com labels de governança padronizados.

4. **Metrics Server via Helm (`k8s_metrics_server.tf`)**:
   - Implantação do Helm chart oficial do `metrics-server` no namespace `kube-system`.
   - Fornece métricas de CPU e memória em tempo real essenciais para o **Horizontal Pod Autoscaler (HPA)** da API.

---

## 🔗 Integração com `oficina-mecanica-infra-base`

Este repositório consome a fundação de rede (VPC, Subnets públicas e privadas, CIDRs) provisionada pelo repositório [`oficina-mecanica-infra-base`](https://github.com/FIAP-15SOAT/oficina-mecanica-infra-base) diretamente via **Remote State** no Amazon S3:

```hcl
data "terraform_remote_state" "aws_base" {
  backend = "s3"
  config = {
    bucket = var.aws_base_state_bucket
    key    = var.aws_base_state_key
    region = var.aws_base_state_region
  }
}
```

---

## 📁 Estrutura do Repositório

```text
.
├── .github/
│   └── workflows/
│       ├── ci.yml               # Validação Terraform e abertura de PR
│       └── cd.yml               # Deploy automatizado (terraform apply)
├── terraform/
│   ├── backend.tf               # Configuração do backend S3 e lock nativo
│   ├── providers.tf             # Providers AWS, Kubernetes, Helm e leitura do remote state da VPC
│   ├── locals.tf                # Nomes padronizados de recursos
│   ├── eks.tf                   # Cluster EKS, Node Group, Log Group e Security Group
│   ├── ecr.tf                   # Repositório Amazon ECR e Lifecycle Policy
│   ├── k8s_namespace.tf         # Namespace da solução (oficina)
│   ├── k8s_metrics_server.tf    # Release Helm do metrics-server
│   ├── variables.tf             # Declaração das variáveis
│   ├── outputs.tf               # Saídas (cluster, ECR, namespace, comandos)
│   ├── terraform.tfvars         # Valores de variáveis padrão
│   └── terraform.tfvars.example
└── .gitignore
```

---

## 💾 Estado Remoto (Remote State)

- **Bucket**: `bkt-oficina-mecanica`
- **Chave (Key)**: `infra/prod-simulated/k8s/terraform.tfstate`
- **Região**: `us-east-1`
- **Lock**: Lock nativo do S3 (`use_lockfile = true`)

---

## ⚙️ Variáveis e Saídas

| Variável | Tipo | Padrão | Descrição |
|---|---|---|---|
| `aws_region` | `string` | `us-east-1` | Região da AWS |
| `project_name` | `string` | `oficina-mecanica` | Nome do projeto |
| `environment` | `string` | `prod-simulated` | Nome do ambiente |
| `kubernetes_version` | `string` | `1.35` | Versão do Kubernetes no EKS |
| `eks_cluster_role_name` | `string` | `""` | Role IAM do cluster EKS (injetada via `vars.EKS_CLUSTER_ROLE_NAME`) |
| `eks_node_role_name` | `string` | `""` | Role IAM dos nós gerenciados (injetada via `vars.EKS_NODE_ROLE_NAME`) |
| `node_instance_type` | `string` | `t3.small` | Tipo de instância EC2 dos nós |
| `node_desired_size` | `number` | `1` | Quantidade desejada de nós |
| `aws_base_state_bucket` | `string` | `bkt-oficina-mecanica` | Bucket S3 do state de rede (infra-base) |
| `aws_base_state_key` | `string` | `infra/prod-simulated/infra-base/terraform.tfstate` | Chave do state de rede (infra-base) |
| `k8s_namespace` | `string` | `oficina` | Namespace Kubernetes a ser criado |
| `enable_metrics_server` | `bool` | `true` | Se deve instalar o Metrics Server via Helm |

> **Nota sobre AWS Academy:** As roles `EKS_CLUSTER_ROLE_NAME` e `EKS_NODE_ROLE_NAME` mudam de ID a cada reinício do lab. Elas são configuradas diretamente no GitHub em **Settings > Secrets and variables > Actions > Variables** e injetadas automaticamente nas esteiras via `TF_VAR_*`, sem necessidade de alterar o código.

### Saídas Exportadas (Outputs)

| Saída | Descrição |
|---|---|
| `cluster_name` | Nome do cluster EKS provisionado |
| `cluster_endpoint` | Endpoint do control plane do EKS |
| `cluster_certificate_authority_data` | Certificado CA do cluster EKS |
| `cluster_version` | Versão ativa do Kubernetes |
| `ecr_repository_url` | URL do repositório ECR da aplicação |
| `k8s_namespace` | Nome do namespace provisionado (`oficina`) |
| `zz_next_steps` | Guia com comandos rápidos para atualizar o `kubeconfig` e validar acesso |

---

## 🚀 Como Executar Localmente

### Pré-requisitos

1. A infraestrutura de rede AWS precisa ter sido previamente provisionada via [`oficina-mecanica-infra-base`](https://github.com/FIAP-15SOAT/oficina-mecanica-infra-base).
2. **Terraform ≥ 1.11.0**.
3. **AWS CLI v2** configurada.

### Passo a Passo

```bash
# 1. Clonar o repositório e entrar na pasta terraform
git clone https://github.com/FIAP-15SOAT/oficina-mecanica-k8s.git
cd oficina-mecanica-k8s/terraform

# 2. Inicializar o Terraform
terraform init

# 3. Visualizar o plano de execução
terraform plan

# 4. Aplicar o provisionamento
terraform apply

# 5. Atualizar kubeconfig local
aws eks update-kubeconfig --region us-east-1 --name eks-oficina-mecanica
```

---

## 🔄 Pipelines de CI/CD

- **CI ([`ci.yml`](.github/workflows/ci.yml))**:
  - **Gatilho**: Push em branches `feature/**` e `fix/**`.
  - **Ações**: `terraform fmt`, `init`, `validate` e `plan` (consumindo o remote state da VPC no S3). Abre PR para `main` ao passar.
- **CD ([`cd.yml`](.github/workflows/cd.yml))**:
  - **Gatilho**: Push na branch `main` ou disparo manual via **Run workflow** (`workflow_dispatch`).
  - **Ações**: `terraform apply -auto-approve` provisionando EKS, Node Group, ECR e manifests Kubernetes. Controlado por `ENABLE_DEPLOY` ou execução manual.

---

## 📐 Decisões Arquiteturais

- [ADR 0001 — Suporte ao HPA da API e dimensionamento do Node Group em função dele](docs/adr/0001-suporte-a-hpa-e-dimensionamento-do-node-group.md)
- [ADR 0002 — Amazon EKS como distribuição gerenciada de Kubernetes](docs/adr/0002-eks-como-distribuicao-gerenciada.md)
- [ADR 0003 — Endpoint do control plane EKS público e privado simultaneamente](docs/adr/0003-endpoint-publico-e-privado-simultaneos.md)
- [ADR 0004 — Amazon ECR com scan-on-push, tags mutáveis e retenção de 20 imagens](docs/adr/0004-ecr-scan-on-push-tags-mutaveis.md)
- [ADR 0005 — Providers Kubernetes/Helm autenticados por token IAM efêmero](docs/adr/0005-auth-providers-k8s-helm-via-token-iam-efemero.md)
- [ADR 0006 — Namespace único compartilhado para todos os recursos da aplicação](docs/adr/0006-namespace-unico-compartilhado.md)

## 👥 Autores

- [Guilherme da Rocha Salvador](https://github.com/guilhermesalvador404)
- [Lucas Almeida da Silva](https://github.com/lucas-almeida-silva)
- [Ramoon Lincoln Barros Camacho](https://github.com/ramooncamacho)
- [Renan Santana Camacho](https://github.com/renancamacho)

## 📄 Licença

Projeto acadêmico (FIAP — 15SOAT), para fins educacionais. Sem licença aberta declarada (`UNLICENSED`).
