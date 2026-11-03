# Grid Intelligence

Plataforma de dados e IA da **Luz do Vale Distribuidora S.A.** no Databricks.

## Visão Geral

Grid Intelligence resolve três dores críticas de uma distribuidora de energia elétrica:
1. **Continuidade do fornecimento** — apuração de DEC e FEC
2. **Perdas Não Técnicas** — priorização de inspeções
3. **Atendimento ao cliente** — inteligência sobre chamados

O projeto segue arquitetura medallion (raw → bronze → silver → gold) e é construído em **8 prompts sequenciais**, cada um entregando uma feature completa com deploy e resultado visível.

## Estrutura do Projeto

```
.
├── .llm/                      # Documentação PRD e contexto
├── resources/                 # Definições de recursos (schemas, volumes)
├── src/                       # Código Python (futuro)
├── prompts/                   # Os 8 prompts de construção
├── databricks.yml            # Configuração do bundle
└── README.md                 # Este arquivo
```

## Ambientes

Dois ambientes isolados por catálogo:

| Ambiente | Catálogo | Uso |
|----------|----------|-----|
| `dev` | `grid_dev` | Desenvolvimento (padrão) |
| `prod` | `grid_intelligence` | Produção |

Os **schemas** (`raw`, `bronze`, `silver`, `gold`) mantêm os mesmos nomes nos dois ambientes.

## Setup Inicial (Prompt 00)

### Pré-requisitos

- Databricks CLI configurado com perfil `grid_intelligence`
- Permissões de administrador na workspace

### 1. Criar Catálogos

Os catálogos devem ser criados manualmente via SQL (o bundle não cria catálogos):

```bash
databricks experimental aitools tools query --profile grid_intelligence \
  "CREATE CATALOG IF NOT EXISTS grid_dev COMMENT 'Catalogo de desenvolvimento da Grid Intelligence'"

databricks experimental aitools tools query --profile grid_intelligence \
  "CREATE CATALOG IF NOT EXISTS grid_intelligence COMMENT 'Catalogo de producao da Grid Intelligence'"

databricks catalogs list --profile grid_intelligence
```

### 2. Conceder Permissões

```bash
databricks grants update CATALOG grid_dev \
  --json '{"changes":[{"principal":"SEU-EMAIL","add":["ALL_PRIVILEGES"]}]}' \
  --profile grid_intelligence

databricks grants update CATALOG grid_intelligence \
  --json '{"changes":[{"principal":"SEU-EMAIL","add":["ALL_PRIVILEGES"]}]}' \
  --profile grid_intelligence
```

### 3. Deploy do Bundle

```bash
# Validar
databricks bundle validate --profile grid_intelligence

# Deploy em dev
databricks bundle deploy -t dev --profile grid_intelligence
```

Isso cria os 4 schemas (`raw`, `bronze`, `silver`, `gold`) e o volume `raw.landing`.

### 4. Verificar

```bash
databricks experimental aitools tools query --profile grid_intelligence "SHOW SCHEMAS IN grid_dev"
databricks experimental aitools tools query --profile grid_intelligence "SHOW VOLUMES IN grid_dev.raw"
```

## Upload de Dados

### Caminhos de Upload

Os arquivos Parquet devem ser organizados em pastas dentro do volume `landing`:

```
/Volumes/grid_dev/raw/landing/unidades_consumidoras/
/Volumes/grid_dev/raw/landing/interrupcoes/
/Volumes/grid_dev/raw/landing/consumo_diario/
/Volumes/grid_dev/raw/landing/chamados/
```

### Via Interface Web

1. Acesse Catalog → `grid_dev` → `raw` → `landing`
2. Crie as pastas (clique com botão direito → Create folder)
3. Faça upload dos arquivos `.parquet` em cada pasta

### Via CLI

Assumindo que os arquivos estão em uma pasta local `./data`:

```bash
# Upload de todas as bases de uma vez
databricks fs cp -r ./data/unidades_consumidoras /Volumes/grid_dev/raw/landing/unidades_consumidoras --overwrite --profile grid_intelligence
databricks fs cp -r ./data/interrupcoes /Volumes/grid_dev/raw/landing/interrupcoes --overwrite --profile grid_intelligence
databricks fs cp -r ./data/consumo_diario /Volumes/grid_dev/raw/landing/consumo_diario --overwrite --profile grid_intelligence
databricks fs cp -r ./data/chamados /Volumes/grid_dev/raw/landing/chamados --overwrite --profile grid_intelligence
```

**Nota:** O prefixo `dbfs:` não é necessário para volumes do Unity Catalog.

## Comandos Úteis

### Listar Arquivos no Volume

```bash
databricks fs ls dbfs:/Volumes/grid_dev/raw/landing --profile grid_intelligence
```

### Recomeçar do Zero

**⚠️ COMANDO DESTRUTIVO — Remove schemas, tabelas, volumes e arquivos:**

```bash
databricks experimental aitools tools query --profile grid_intelligence \
  "DROP CATALOG IF EXISTS grid_dev CASCADE"
```

Sempre confirme antes de executar. Depois de dropar, siga o setup inicial novamente.

### Deploy em Produção

```bash
databricks bundle deploy -t prod --profile grid_intelligence
```

## Bases de Dados

Quatro bases sintéticas em Parquet:

| Base | Grão | Volume | Defeitos Propositais |
|------|------|--------|----------------------|
| `unidades_consumidoras` | UC | 4.000 linhas | — |
| `interrupcoes` | evento | 1.383 linhas | Algumas < 3 minutos |
| `consumo_diario` | UC × dia | ~5,85 milhões | Nulos, negativos, duplicatas |
| `chamados` | ligação | 2.801 linhas | Dados pessoais |

**Período:** 4 anos de histórico com crescimento de 30% a.a. e sazonalidade de verão.

## Sequência de Construção

| # | Prompt | Entrega | Arquivo |
|---|--------|---------|---------|
| 00 | Setup | Contexto, catálogos, schemas, volume | `prompts/00-setup.md` ✅ |
| 01 | Bronze | Ingestão fiel das quatro bases | `prompts/01-bronze.md` |
| 02 | Silver — números | Cadastro limpo, RN-01, dedup, baseline | `prompts/02-silver-numeros.md` |
| 03-A ou 03-B | Silver — texto | Anonimização e enriquecimento | `prompts/03-silver-texto-*.md` |
| 04 | Gold | Entregas de negócio e metric view | `prompts/04-gold.md` |
| 05 | Dashboard | Painel AI/BI | `prompts/05-dashboard.md` |
| 06 | Agente | Copiloto conversacional | `prompts/06-agente.md` |
| 07 | Relatório | Relatório executivo e queries | `prompts/07-relatorio-e-demonstracao.md` |

## Documentação

- **PRD completo:** `.llm/prd.md`
- **Glossário e regras:** 14 regras de negócio documentadas no PRD
- **Convenções:** Português sem acentuação, catálogo via `${var.catalog}`

## Tecnologias

- Databricks Lakehouse Platform
- Unity Catalog (governança)
- Delta Lake (tabelas)
- SQL + Python (transformações)
- AI/BI Dashboards (visualização)
- Genie / Agent Bricks (agente conversacional)
- Databricks Asset Bundles (IaC)

## Suporte

Este é um projeto educacional construído ao vivo, com foco em simplicidade e legibilidade.

**Perfil da CLI:** Todos os comandos usam `--profile grid_intelligence`.
