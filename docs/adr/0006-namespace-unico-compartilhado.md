# ADR 0006: Namespace único compartilhado para todos os recursos da aplicação

## Status

Aceito — 2026-09-07

## Contexto

`terraform/k8s_namespace.tf` cria um único namespace Kubernetes (`oficina`, com labels `app.kubernetes.io/part-of` e `managed-by: terraform`) onde todos os recursos da aplicação (API, MailHog, HPA) e os workloads de plataforma provisionados por este repositório convivem. Não há separação por ambiente (ex.: `oficina-staging`/`oficina-prod`) nem por domínio de negócio dentro do cluster.

## Decisão

Manter um **único namespace compartilhado** (`oficina`) para todos os recursos da aplicação neste cluster, em vez de namespaces separados por ambiente ou por domínio funcional.

## Alternativas consideradas

### Um namespace por ambiente (`oficina-staging`, `oficina-prod`)

Isolaria ambientes diferentes dentro do mesmo cluster físico, permitindo testar mudanças em `staging` sem afetar `prod`. Descartada porque o projeto já opera com um único ambiente `prod-simulated` (ver ADR 0001 do `oficina-mecanica-infra-base`) — não há hoje um segundo ambiente rodando simultaneamente que justificasse a separação, e criar um cluster ou namespace adicional só para simular "staging" consumiria crédito de laboratório sem uso funcional real nesta fase do projeto.

### Um namespace por domínio de negócio (ex.: `oficina-auth`, `oficina-work-orders`)

Seguiria um padrão comum em arquiteturas de microsserviços, isolando recursos por área de responsabilidade. Descartada porque a aplicação é um **monólito modular** (ADR 0007 do `oficina-mecanica-app`) — um único processo/Deployment serve todos os domínios de negócio, então não existe uma fronteira de deploy real entre "auth" e "work-orders" para justificar namespaces separados; toda a API sobe e desce como uma unidade só.

## Consequências

### Positivas

- **Configuração mínima**: um namespace só significa menos RBAC, menos `NetworkPolicy` (se algum dia adotadas) e menos superfície de configuração para manter sincronizada.
- **Coerente com a arquitetura de monólito modular**: como a aplicação já é um único processo implantado como uma unidade (ADR 0007 do `oficina-mecanica-app`), um único namespace reflete fielmente essa unidade de deploy, sem uma separação artificial que a arquitetura da aplicação não sustenta.

### Negativas / Trade-offs

- **Sem isolamento de RBAC ou de rede por domínio**: qualquer recurso dentro do namespace `oficina` compartilha o mesmo espaço de nomes e, na ausência de `NetworkPolicy` customizada, a mesma superfície de alcance de rede interna — um comprometimento de um componente não fica isolado de outro por fronteira de namespace.
- **Sem separação de ambiente dentro do cluster**: uma mudança aplicada ao namespace único afeta imediatamente o único ambiente existente, sem uma réplica isolada para validar antes — o projeto depende inteiramente do pipeline de CI/CD (fmt/validate/plan antes do apply) como sua rede de segurança, não de isolamento de namespace.

### Riscos aceitos

- **Ausência de ambiente de staging isolado dentro do cluster**: aceito para o escopo e orçamento deste laboratório; uma futura expansão do projeto para múltiplos ambientes deveria reavaliar esta decisão.

## Referências

- `terraform/k8s_namespace.tf` — definição do namespace `oficina`.
- [`oficina-mecanica-app` › ADR 0007 — Padrão de comunicação: REST síncrono num monólito modular](https://github.com/FIAP-15SOAT/oficina-mecanica-app/blob/master/docs/adr/0007-padrao-de-comunicacao-rest-monolito.md)
- [`oficina-mecanica-infra-base` › ADR 0001 — Escolha da nuvem e infra base](https://github.com/FIAP-15SOAT/oficina-mecanica-infra-base/blob/main/docs/adr/0001-escolha-de-nuvem-e-infra-base.md)
