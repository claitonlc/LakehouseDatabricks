# Grid Intelligence — Product Requirements Document

## Visão Geral

**Grid Intelligence** é a plataforma de dados e IA da **Luz do Vale Distribuidora S.A.**, uma distribuidora de energia elétrica fictícia. O projeto combina engenharia de dados, machine learning e inteligência artificial para resolver três dores críticas do negócio, todas mensuráveis em dinheiro e reguladas pela ANEEL.

---

## Contexto de Negócio

Uma distribuidora de energia opera sob regulação da ANEEL e enfrenta três dores simultâneas:

### 1. Continuidade do Fornecimento
Interromper além do limite regulatório gera compensação financeira automática ao consumidor. Em 2024, as distribuidoras brasileiras pagaram mais de **R$ 1,1 bilhão** em compensações.

### 2. Perdas Não Técnicas (PNT)
Energia distribuída e não faturada — furto, fraude e erro de medição. Em 2025, somaram **~R$ 11,5 bilhões**, dos quais **~R$ 7,9 bilhões** foram repassados à tarifa.

### 3. Atendimento ao Cliente
Milhares de ligações viram transcrição e ninguém lê. Dentro delas está o aviso antecipado da reclamação na ouvidoria.

---

## Glossário

Use estes termos sem sinônimo aproximado:

| Termo | Definição |
|-------|-----------|
| **UC — Unidade Consumidora** | O ponto de entrega de energia. **Não é sinônimo de cliente**: um cliente pode ter várias UCs |
| **Conjunto** | Subdivisão geográfica da área de concessão. É a unidade de agregação do regulador |
| **DEC** | Duração Equivalente de Interrupção por UC — tempo médio, em horas, sem fornecimento |
| **FEC** | Frequência Equivalente de Interrupção por UC — número médio de interrupções |
| **PNT** | Perdas Não Técnicas |
| **Prioridade de inspeção** | Classificação de quanto uma UC merece visita técnica |

---

## Regras de Negócio

### RN-01 — Filtro de 3 minutos
Só interrupções com **3 minutos ou mais** entram na apuração de DEC e FEC. A regra vive na camada de transformação, nunca no relatório.

### RN-04 — Definição única de DEC/FEC
DEC e FEC têm **uma única definição** no sistema, consumida por dashboard, agente e relatório.

### RN-06 — Dois eixos para inspeção
Uma UC é candidata a inspeção quando o consumo cai em **dois eixos simultâneos**: contra o próprio baseline **e** enquanto a vizinhança permanece estável. Só o primeiro eixo apontaria o bairro inteiro depois de um apagão.

### RN-07 — Prioridade, não culpa
A saída da detecção é **prioridade de inspeção** — alta, média, baixa. **Nunca** um rótulo de fraude, furto ou culpa. Queda de consumo também é mudança de morador, imóvel desocupado, defeito de medidor e erro de leitura. Em setor regulado a diferença é jurídica. Nenhuma coluna, variável ou comentário do projeto pode usar as palavras "fraude", "furto" ou "culpado" como rótulo de saída.

### RN-09 — Mascaramento antes da análise
Dado pessoal em transcrição é **mascarado antes** de qualquer análise de conteúdo.

### RN-10 — Preservação com acesso restrito
O texto original identificado é preservado com **acesso restrito**. Duas proteções que coexistem: uma na leitura, outra na análise.

### RN-11 — Bronze não filtra
A camada de ingestão **não filtra, não corrige e não aplica regra de negócio**. Leitura inválida de medidor é um fato sobre o medidor. Filtrar na ingestão parece limpeza; é destruição de evidência.

### RN-12 — Rastreabilidade na ingestão
Todo registro ingerido carrega origem e momento de ingestão.

### RN-13 — Agente lê apenas gold
O agente conversacional acessa **apenas a camada de negócio**.

### RN-14 — Descrição em gold
As entidades da **camada gold** carregam descrição em linguagem de negócio — é o que o agente lê. Bronze e silver não precisam: são passagem.

---

## Modelo de Informação

### Camadas

O projeto segue a arquitetura medallion com quatro camadas:

```
raw     → arquivos Parquet do volume, sem transformação
bronze  → ingestão fiel, sem regra de negócio (RN-11, RN-12)
silver  → limpeza, deduplicação, enriquecimento, aplicação de regras (RN-01, RN-06, RN-09)
gold    → agregações de negócio, com descrições (RN-14)
```

### Bases de Dados

Quatro bases sintéticas, em Parquet:

| Base | Grão | Volume | Descrição |
|------|------|--------|-----------|
| `unidades_consumidoras` | uma por ponto de entrega | 4.000 | Cadastro de UCs com localização e conjunto |
| `interrupcoes` | uma por evento de rede | 1.383 | Interrupções ocorridas, algumas < 3 min |
| `consumo_diario` | uma por UC por dia | ~5,85 milhões | 4 anos de histórico com crescimento 30% a.a. |
| `chamados` | uma por ligação | 2.801 | Transcrições com sazonalidade de verão |

**Defeitos propositais no dataset:**
- Consumo nulo, negativo, fisicamente impossível
- Linhas duplicadas
- Interrupções abaixo de 3 minutos
- Dados pessoais nas transcrições

Esses defeitos existem para as validações de qualidade e a RN-01 terem o que fazer.

---

## Entregas de Negócio

O projeto tem quatro entregas finais, todas consumidas pela camada gold:

### 1. Continuidade — DEC e FEC por conjunto
Apuração regulatória que mede a confiabilidade do fornecimento. RN-01 e RN-04 aplicam.

### 2. Perdas Não Técnicas — Prioridade de inspeção
Ranking de UCs candidatas a visita técnica. RN-06 e RN-07 aplicam. Resultado é **prioridade**, nunca rótulo de fraude.

### 3. Atendimento — Inteligência de chamados
Classificação automática de urgência e extração de entidades (UC, conjunto, categoria). RN-09 e RN-10 aplicam: dado pessoal é mascarado antes da análise.

### 4. Painel Operacional (AI/BI Dashboard)
Visualização executiva com duas páginas, consumida pelo agente conversacional e pela diretoria.

### 5. Agente Conversacional
Copiloto em português que responde perguntas de negócio sobre a camada gold (RN-13).

---

## Diretriz de Simplicidade

Este projeto é construído **ao vivo, em aula**. Código que ninguém consegue ler na tela em dez segundos não serve, mesmo que seja mais robusto.

**Escreva o mínimo que faz a coisa funcionar:**

- **Sem expectations e sem `CONSTRAINT`** nas tabelas. Regra de negócio vira `WHERE`.
- **Sem `COMMENT` em bronze e silver.** Só a **gold** e a **metric view** levam descrição.
- **Sem `TBLPROPERTIES`, `CLUSTER BY` e afins**, a menos que sem eles quebre.
- **Sem tratamento de caso que o dataset não tem.** Não invente defesa para dado que não existe.
- **Um `SELECT` direto vence um `WITH` de quatro CTEs.** Só quebre em CTE quando a query realmente não couber de cabeça.

Comentário no código só onde a decisão **não é óbvia pelo código**.

---

## Convenções Obrigatórias

- Todo texto e todo nome em **português do Brasil**
- Nomes de entidades, colunas e arquivos **sem acentuação**
- **Nenhum nome de catálogo fixado em código.** Catálogo vem de `${var.catalog}` no `databricks.yml`
- **Nenhum nome de schema fixado.** Schema vem de `${resources.schemas.<camada>.name}`
- **Nenhum nome de modelo de IA fixado.** Use as funções `ai_*` do Databricks
- Perfil da CLI: `grid_intelligence`. Todo comando leva `--profile grid_intelligence`

---

## Ambientes

Dois ambientes, isolados por catálogo:

| Ambiente | Catálogo | Schemas | Uso |
|----------|----------|---------|-----|
| `dev` | `grid_dev` | raw, bronze, silver, gold | Desenvolvimento |
| `prod` | `grid_intelligence` | raw, bronze, silver, gold | Produção |

Os **schemas mantêm os nomes exatos** nos dois ambientes. O SQL é portável: `${var.catalog}.bronze.chamados` resolve para `grid_dev.bronze.chamados` em dev e `grid_intelligence.bronze.chamados` em prod.

---

## Volume de Dados

**Dataset:** 4 anos de histórico  
**Crescimento:** 30% ao ano na carga  
**Sazonalidade:** Chamados dobram no verão (dezembro a março)  
**Total:** ~5,85 milhões de linhas de consumo + 4.000 UCs + 1.383 interrupções + 2.801 chamados

---

## Sequência de Construção

O projeto é construído em **8 prompts sequenciais**. Cada um entrega uma feature completa, com deploy e resultado visível:

| # | Prompt | Entrega |
|---|--------|---------|
| 00 | Setup | Contexto, regras, schemas, volume |
| 01 | Bronze | Ingestão fiel das quatro bases |
| 02 | Silver — números | Cadastro limpo, RN-01, dedup, baseline |
| 03-A ou 03-B | Silver — texto | Anonimização e enriquecimento (IA ou regex) |
| 04 | Gold | As quatro entregas e a metric view |
| 05 | Dashboard | Painel AI/BI de duas páginas |
| 06 | Agente | Copiloto conversacional em português |
| 07 | Relatório | Relatório executivo e queries de prova |

---

## Tecnologias

- **Databricks Lakehouse Platform**
- **Unity Catalog** (governança)
- **Delta Lake** (formato de tabela)
- **SQL + Python** (transformações)
- **AI/BI Dashboards** (visualização)
- **Genie / Agent Bricks** (agente conversacional)
- **Databricks Asset Bundles (DABs)** (infraestrutura como código)

---

## Critérios de Aceite do Projeto

No final dos 8 prompts, o projeto está completo quando:

1. Todos os dados estão ingeridos e transformados pelas quatro camadas
2. As 14 regras de negócio estão implementadas e verificáveis
3. O dashboard mostra DEC, FEC, prioridades de inspeção e chamados
4. O agente conversacional responde perguntas sobre Campinas com dados corretos
5. O relatório executivo apresenta as quatro entregas com queries de prova
6. O código é legível ao vivo e segue as diretrizes de simplicidade

---

**Versão:** 1.0  
**Data:** 2026-11-02  
**Projeto:** Grid Intelligence  
**Cliente:** Luz do Vale Distribuidora S.A. (fictícia)
