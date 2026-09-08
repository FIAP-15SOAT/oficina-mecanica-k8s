# ADR 0005: Providers Kubernetes/Helm autenticados por token IAM efêmero, sem kubeconfig estático

## Status

Aceito — 2026-09-07

## Contexto

Os providers `kubernetes` e `helm` do Terraform (`terraform/providers.tf`) precisam de credenciais para falar com a API do cluster EKS recém-criado, para provisionar o namespace (`k8s_namespace.tf`) e o Metrics Server (`k8s_metrics_server.tf`) na mesma execução de `terraform apply` que cria o cluster. A forma como esses providers se autenticam é uma decisão que se repete em toda execução do pipeline e que interage diretamente com o contexto de credenciais rotativas do AWS Academy (roles e sessões que mudam a cada reinício do laboratório — ver ADR 0001 do `oficina-mecanica-infra-base`).

## Decisão

Autenticar os providers `kubernetes` e `helm` via **`data "aws_eks_cluster_auth"`**, que gera um **token IAM efêmero** de curta duração no momento da execução do Terraform, combinado com o endpoint e o certificado CA lidos diretamente dos atributos do `aws_eks_cluster` recém-criado (`aws_eks_cluster.eks_cluster.endpoint`, `.certificate_authority[0].data`). Não há kubeconfig estático gerado ou versionado em nenhum lugar — cada execução do Terraform obtém um token novo, válido só para aquela execução.

## Alternativas consideradas

### Kubeconfig estático gerado e armazenado como secret

Geraria um arquivo de kubeconfig (via `aws eks update-kubeconfig`) e o armazenaria como um GitHub Secret, reutilizado em execuções futuras. Descartada porque um token de autenticação do EKS tem vida curta (minutos) — um kubeconfig estático ficaria inválido rapidamente e precisaria ser regenerado e re-armazenado manualmente a cada expiração, um processo operacional frágil e desnecessário quando o Terraform já pode gerar o token sob demanda a cada execução.

### `kubectl`/Helm CLI chamados via `local-exec` fora dos providers nativos do Terraform

Executaria `kubectl apply`/`helm install` como comandos de shell dentro de um `null_resource`, autenticando via `aws eks update-kubeconfig` no início do step. Descartada porque perderia o gerenciamento de estado nativo do Terraform para esses recursos (o namespace e o release Helm ficariam fora do grafo de dependências e do `terraform plan`/`destroy` declarativo) — os providers nativos `kubernetes`/`helm` mantêm esses recursos como cidadãos de primeira classe do state, com todo o benefício de plan/diff que isso traz.

## Consequências

### Positivas

- **Nenhuma credencial de longa duração para o cluster é armazenada em lugar nenhum** (nem GitHub Secret, nem arquivo local) — o token é gerado, usado e descartado dentro da mesma execução.
- **Coerente com o contexto de credenciais rotativas do AWS Academy**: como as próprias credenciais AWS da execução já são temporárias (`AWS_SESSION_TOKEN`), gerar um token EKS igualmente efêmero a partir delas não introduz uma segunda forma de credencial de vida mais longa no meio do fluxo.
- **Namespace e Metrics Server ficam sob gerenciamento de estado do Terraform**, com `plan`/`destroy` declarativos, não scripts imperativos.

### Negativas / Trade-offs

- **Toda execução do Terraform que toque nesses recursos precisa ter credenciais AWS válidas no momento exato da execução** — não há como reaplicar apenas o namespace/Helm release usando um kubeconfig previamente salvo se as credenciais AWS da sessão expiraram nesse meio-tempo.
- **Depuração manual fora do Terraform exige gerar o próprio kubeconfig** (`aws eks update-kubeconfig`) separadamente — um desenvolvedor que só quer rodar `kubectl get pods` não reaproveita nada do que o Terraform já autenticou.

### Riscos mitigados

- **Vazamento de credencial de cluster de longa duração**: mitigado por nunca persistir um token ou kubeconfig — cada execução gera o seu, válido só enquanto ela dura.

## Referências

- `terraform/providers.tf` — configuração dos providers `kubernetes` e `helm` via `data.aws_eks_cluster_auth`.
- [`oficina-mecanica-infra-base` › ADR 0001 — Escolha da nuvem (contexto de credenciais rotativas do AWS Academy)](https://github.com/FIAP-15SOAT/oficina-mecanica-infra-base/blob/main/docs/adr/0001-escolha-de-nuvem-e-infra-base.md)
