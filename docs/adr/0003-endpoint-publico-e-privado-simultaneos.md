# ADR 0003: Endpoint do control plane EKS público e privado simultaneamente

## Status

Aceito — 2026-09-07

## Contexto

`terraform/eks.tf` configura o `vpc_config` do cluster EKS com `endpoint_private_access = true` **e** `endpoint_public_access = true` ao mesmo tempo. Isso significa que o endpoint da API do Kubernetes é alcançável tanto de dentro da VPC (nós do cluster, qualquer recurso na rede privada) quanto da internet pública — uma escolha de superfície de exposição que nunca foi justificada em nenhum documento do repositório até esta ADR.

O Terraform que provisiona o cluster roda no GitHub Actions (`cd.yml`), fora da VPC — ou seja, o `apply` que cria/atualiza o cluster já precisa alcançar o endpoint de alguma rede externa à VPC.

## Decisão

Manter **ambos os endpoints habilitados simultaneamente**: `endpoint_private_access = true` (para os nós do cluster e qualquer recurso dentro da VPC alcançarem a API do control plane pela rede interna) e `endpoint_public_access = true` (para permitir que o pipeline de CD, rodando em runners do GitHub Actions fora da VPC, e qualquer desenvolvedor local execute `kubectl`/`terraform apply` sem precisar de VPN ou bastion host).

## Alternativas consideradas

### Apenas `endpoint_private_access = true` (endpoint só privado)

Reduziria a superfície de exposição do control plane à internet pública, restringindo o acesso à API do Kubernetes só a quem estiver dentro da VPC. Descartada nesta entrega porque o pipeline de CD roda em runners hospedados do GitHub Actions, fora da VPC — sem um Runner self-hosted dentro da rede privada, ou uma VPN/bastion host para alcançar o endpoint privado, o próprio pipeline de deploy perderia acesso ao cluster. Provisionar qualquer uma dessas alternativas (runner self-hosted, VPN, bastion) exigiria infraestrutura adicional fora do orçamento de laboratório disponível.

### Apenas `endpoint_public_access = true`, restrito por `public_access_cidrs`

Manteria o endpoint acessível de fora da VPC (necessário para o CD) mas restringiria os IPs de origem permitidos a uma lista explícita (ex.: os ranges de IP dos runners do GitHub Actions). Descartada porque os ranges de IP dos runners hospedados do GitHub Actions **mudam dinamicamente** e não são fixos o suficiente para uma lista de CIDRs estável — manter essa lista atualizada exigiria consultar a API de metadados de IP do GitHub a cada execução, adicionando complexidade ao pipeline sem eliminar de fato o acesso público (só restringindo por origem, que já muda com frequência).

### Runner self-hosted dentro da VPC (GitHub Actions self-hosted runner)

Permitiria manter o endpoint só privado, com o runner de CD residindo dentro da própria VPC e alcançando o cluster pela rede interna. Descartada por custo e complexidade operacional: exigiria provisionar e manter uma instância EC2 rodando o runner continuamente (ou sob demanda), com seu próprio ciclo de vida e patching — infraestrutura adicional que o laboratório AWS Academy não comporta confortavelmente dentro do orçamento já consumido por EKS, RDS e NAT Gateway.

## Consequências

### Positivas

- **Pipeline de CD funciona sem infraestrutura adicional** (VPN, bastion, runner self-hosted): o `terraform apply` e o `kubectl` dos runners hospedados do GitHub Actions alcançam o cluster diretamente pelo endpoint público.
- **Desenvolvedores locais conseguem `kubectl`/depurar o cluster diretamente**, sem precisar estar dentro da VPC.

### Negativas / Trade-offs

- **Superfície de ataque maior**: a API do Kubernetes fica exposta à internet pública, dependendo inteiramente da autenticação (IAM, via `aws-iam-authenticator`) e não de isolamento de rede como camada adicional de defesa.
- **Sem restrição de CIDR de origem no endpoint público**: qualquer IP na internet pode tentar se conectar à API (a autenticação/autorização do EKS ainda se aplica, mas não há filtro de rede antes dela).

### Riscos aceitos

- **Exposição do control plane à internet pública**: aceito porque a autenticação IAM do EKS é a barreira real de acesso (não há dados sensíveis expostos por um endpoint alcançável sem credencial válida), e o custo de eliminar essa exposição (VPN, bastion ou runner self-hosted) não cabe no orçamento de laboratório. Uma conta de produção real deveria reavaliar essa decisão, restringindo por `public_access_cidrs` ou eliminando o acesso público em favor de um runner self-hosted dentro da VPC.

## Referências

- `terraform/eks.tf` — `vpc_config` do `aws_eks_cluster`.
- `.github/workflows/cd.yml` — pipeline que depende do endpoint público para `terraform apply`.
- [ADR 0002 — Amazon EKS como distribuição gerenciada de Kubernetes](0002-eks-como-distribuicao-gerenciada.md)
