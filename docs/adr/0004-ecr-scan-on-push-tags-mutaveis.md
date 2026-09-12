# ADR 0004: Amazon ECR com scan-on-push, tags mutáveis e retenção de 20 imagens

## Status

Aceito — 2026-09-07

## Contexto

`terraform/ecr.tf` provisiona um repositório Amazon ECR dedicado às imagens de container da API (`oficina-mecanica-api`), com três configurações que juntas formam uma política de gestão de imagens: varredura automática de vulnerabilidades no push (`scan_on_push = true`), criptografia AES-256, mutabilidade de tag (`image_tag_mutability = "MUTABLE"`) e uma lifecycle policy mantendo as últimas 20 imagens. Nenhuma dessas escolhas tinha, até agora, um registro do porquê.

O pipeline de CD do `oficina-mecanica-api` (`cd.yml`, job `build-push-image`) já publica **duas tags por build**: `${ECR_REPOSITORY}:${COMMIT_SHA}` — única por commit, nunca reescrita — e `${ECR_REPOSITORY}:latest`, reescrita a cada novo build. O próprio deploy (`Render deployment manifest with immutable image`, `cd.yml`) usa exclusivamente a tag por `COMMIT_SHA` no manifesto do `Deployment` — a tag `latest` nunca é referenciada por nenhum manifesto Kubernetes, servindo apenas como um ponteiro flutuante de conveniência (ex.: para alguém puxar manualmente a imagem mais recente fora do fluxo de deploy).

## Decisão

Configurar o repositório ECR com:

- **`scan_on_push = true`**: toda imagem enviada é varrida automaticamente por vulnerabilidades conhecidas (CVEs) no momento do push, sem exigir um passo manual ou scanner externo.
- **`image_tag_mutability = "MUTABLE"`**: permite que a tag `latest` seja reescrita a cada build — necessário porque o pipeline publica essa tag em **todo** build, e uma política `IMMUTABLE` rejeitaria o segundo push da mesma tag, quebrando o pipeline no build seguinte ao primeiro. O deploy de fato, no entanto, nunca depende dessa tag: ele referencia a imagem pela tag única de `COMMIT_SHA`, que já é efetivamente imutável na prática (nunca reescrita, pois cada commit gera um SHA novo).
- **Lifecycle policy mantendo as últimas 20 imagens**: imagens além desse número são automaticamente expiradas, controlando o custo de armazenamento sem intervenção manual.
- **Criptografia AES-256** em repouso, o padrão gerenciado pela AWS para o ECR.

## Alternativas consideradas

### `image_tag_mutability = "IMMUTABLE"`

Eliminaria por completo o risco de qualquer tag ser reescrita, reforçando por política do próprio ECR o que a tag por `COMMIT_SHA` já garante na prática. Descartada porque quebraria o pipeline de CD tal como existe hoje: o job `build-push-image` publica a tag `latest` em todo build (`cd.yml`, passo `Build and Push Image`), e uma política `IMMUTABLE` rejeita o push de uma tag que já existe — o segundo build após adotar `IMMUTABLE` falharia ao tentar reescrever `latest`. Adotar `IMMUTABLE` exigiria primeiro remover a publicação da tag `latest` do pipeline (uma mudança de processo, não só de infraestrutura), o que fica registrado como melhoria recomendada, já que o deploy real não depende dela.

### Sem lifecycle policy (reter todas as imagens indefinidamente)

Manteria histórico completo de todas as imagens já publicadas, sem risco de expirar uma imagem ainda necessária. Descartada por custo: o armazenamento do ECR é cobrado por volume, e reter indefinidamente todas as imagens de um pipeline que builda a cada push cresceria sem limite — manter as últimas 20 é suficiente para qualquer rollback razoável dentro do ciclo de vida do laboratório, a um custo previsível.

### `scan_on_push = false`, com scanner de vulnerabilidade externo (ex.: Trivy no CI)

Já existe uma etapa de SAST no pipeline do `oficina-mecanica-api` (ADR 0014); um scanner externo dedicado a imagem poderia rodar ali. Descartada como substituto do `scan_on_push` nativo do ECR (embora nada impeça as duas coexistirem) porque o scan nativo roda automaticamente em toda imagem publicada, sem exigir manutenção de uma ferramenta adicional no pipeline nem a gestão de sua própria base de CVEs.

## Consequências

### Positivas

- **Vulnerabilidades conhecidas detectadas automaticamente** a cada push, sem esforço adicional de pipeline.
- **Custo de armazenamento controlado** pela lifecycle policy, sem exigir limpeza manual periódica do repositório.
- **Deploy reprodutível por construção**: como o manifesto do `Deployment` referencia a imagem pela tag de `COMMIT_SHA`, não por `latest`, cada deploy já é rastreável a um commit exato — a mutabilidade da tag `latest` não compromete essa garantia, pois ela nunca é usada para deploy.

### Negativas / Trade-offs

- **`MUTABLE` permite que a tag `latest` mude de digest silenciosamente**: qualquer pessoa ou script que dependa de `latest` fora do fluxo de deploy oficial (ex.: um `docker pull` manual de depuração) pode obter uma imagem diferente a cada build, sem aviso — um risco que só se materializa fora do caminho de deploy real, já que este usa `COMMIT_SHA`.
- **A mutabilidade vale para o repositório inteiro**: o ECR não permite tornar apenas a tag `latest` mutável mantendo as demais imutáveis — a política é por repositório, então a tag `COMMIT_SHA` também é tecnicamente reescrevível, mesmo que o pipeline nunca a reescreva na prática.
- **Janela de retenção limitada a 20 imagens**: um rollback para uma versão muito antiga (além das últimas 20 publicadas) não seria possível sem rebuildar a imagem a partir do código-fonte histórico.

### Riscos mitigados

- **Deploy de imagem com vulnerabilidade conhecida não detectada**: mitigado pelo scan automático no push.
- **Custo de armazenamento crescendo sem limite**: mitigado pela lifecycle policy de 20 imagens.

## Referências

- `terraform/ecr.tf` — configuração do repositório ECR.
- [`oficina-mecanica-api` › ADR 0014 — Pipelines de CI, CD, SAST e DAST separados](https://github.com/FIAP-15SOAT/oficina-mecanica-api/blob/main/docs/adr/0014-pipelines-ci-cd-sast-dast-separados.md)
