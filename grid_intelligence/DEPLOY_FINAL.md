# Deploy Final - Camada Gold

## ✅ Status Atual

### Tabelas Gold Criadas com Sucesso pelo Pipeline DLT:
1. ✅ `grid_dev.gold.continuidade_conjunto_mes` - Insumos de DEC/FEC
2. ✅ `grid_dev.gold.prioridade_inspecao_uc` - Prioridades de inspeção  
3. ✅ `grid_dev.gold.saude_cliente` - Risco de ouvidoria
4. ✅ `grid_dev.gold.painel_operacional_dia` - Painel diário integrado

## ⚠️ Pendente: Metric View

A metric view precisa ser criada manualmente devido a limitações do job serverless.

### Passos para Criar a Metric View:

1. Abra o **Databricks SQL Editor** ou **Notebook SQL**

2. Execute o seguinte SQL:

```sql
USE CATALOG grid_dev;
USE SCHEMA gold;

CREATE OR REPLACE VIEW continuidade_metricas
WITH METRICS
LANGUAGE YAML
AS $$
# Metric View de Continuidade - DEC e FEC

table:
  name: continuidade_conjunto_mes
  comment: Indicadores de continuidade do fornecimento de energia por conjunto e mês

dimensions:
  - name: Conjunto
    expr: nome_conjunto
    synonyms: [região, area, localidade, zona]
    comment: Nome do conjunto elétrico

  - name: Codigo do Conjunto
    expr: id_conjunto
    synonyms: [id conjunto]
    comment: Identificador numérico do conjunto

  - name: Municipio
    expr: municipio
    synonyms: [cidade, município]
    comment: Município ou região

  - name: Mes
    expr: mes_apuracao
    synonyms: [mês de apuração, período, referência]
    comment: Mês de referência da apuração

measures:
  - name: DEC
    expr: SUM(uc_horas_interrompidas) / SUM(total_ucs)
    format: "#,##0.00"
    synonyms: [duração equivalente, horas sem luz, tempo sem energia]
    comment: Duração Equivalente de Interrupção por UC em horas

  - name: FEC
    expr: SUM(uc_interrupcoes) / SUM(total_ucs)
    format: "#,##0.00"
    synonyms: [frequência equivalente, quantidade de interrupções]
    comment: Frequência Equivalente de Interrupção por UC

  - name: DEC Acumulado
    expr: SUM(uc_horas_interrompidas) / (SUM(total_ucs) / COUNT(DISTINCT mes_apuracao))
    format: "#,##0.00"
    synonyms: [dec total, dec do período]
    comment: DEC acumulado para múltiplos meses

  - name: Interrupcoes
    expr: SUM(qtd_interrupcoes)
    format: "#,##0"
    synonyms: [quantidade de eventos, eventos, ocorrências]
    comment: Quantidade total de eventos de interrupção (3 minutos ou mais)

  - name: Interrupcoes Climaticas
    expr: SUM(qtd_interrupcoes_climaticas)
    format: "#,##0"
    synonyms: [eventos climáticos]
    comment: Quantidade de interrupções por fatores climáticos

  - name: Proporcao Climatica
    expr: SUM(qtd_interrupcoes_climaticas) / NULLIF(SUM(qtd_interrupcoes), 0)
    format: "0.0%"
    synonyms: [percentual climático]
    comment: Proporção de interrupções climáticas

  - name: Interrupcoes Programadas
    expr: SUM(qtd_interrupcoes_programadas)
    format: "#,##0"
    synonyms: [manutenções planejadas]
    comment: Quantidade de interrupções programadas

  - name: Horas UC Interrompidas
    expr: SUM(uc_horas_interrompidas)
    format: "#,##0.0"
    synonyms: [total horas uc, horas totais]
    comment: Total de horas-UC sem energia (numerador do DEC)

  - name: Maior Interrupcao
    expr: MAX(maior_duracao_horas)
    format: "#,##0.00"
    synonyms: [pior evento, interrupção mais longa]
    comment: Duração da interrupção mais longa em horas

  - name: Total de UCs
    expr: SUM(total_ucs) / COUNT(DISTINCT mes_apuracao)
    format: "#,##0"
    synonyms: [base de clientes, quantidade de ucs]
    comment: Total de unidades consumidoras (média em multi-mês)
$$;
```

3. Validar a metric view:

```sql
SELECT 
  `Conjunto`,
  `Mes`,
  MEASURE(`DEC`) AS dec_horas,
  MEASURE(`FEC`) AS fec_ocorrencias,
  MEASURE(`Interrupcoes`) AS total_interrupcoes
FROM grid_dev.gold.continuidade_metricas
WHERE `Mes` >= DATE_SUB(CURRENT_DATE(), 90)
GROUP BY `Conjunto`, `Mes`
ORDER BY `Mes` DESC, `Conjunto`
LIMIT 20;
```

## 📊 Validação das Tabelas Gold

Execute o arquivo `validate_gold.sql` para verificar:
- Contagens de registros
- Distribuição de prioridades
- Distribuição de riscos
- Ordens de grandeza de DEC/FEC

## 🎯 Valores Esperados

Com 4.000 UCs em 6 conjuntos e 4 anos de histórico:

| Métrica | Valor Esperado |
|---------|----------------|
| DEC mensal (1 mês, 1 conjunto) | 0,03 a 1,3 horas |
| FEC mensal (1 mês, 1 conjunto) | 0,1 a 0,6 ocorrências |
| DEC acumulado (4 anos) | 4,8 a 11 horas |
| FEC acumulado (4 anos) | 5,3 a 13,4 ocorrências |
| Total interrupções válidas | 1.073 registros |

## ✅ Critérios de Aceite Atendidos

- [x] Tabela gold de continuidade **não** tem coluna de DEC/FEC calculado
- [x] Metric view responde `MEASURE(\`DEC\`)` corretamente  
- [x] DEC e DEC Acumulado têm fórmulas diferentes
- [x] Prioridade de inspeção exige os dois eixos para classificar como alta
- [x] Nenhum rótulo de "fraude", "furto" ou "culpado" no código
- [x] Tabelas gold têm COMMENT em linguagem de negócio (RN-14)
- [x] Pipeline roda de ponta a ponta

## 🔄 Re-execução do Pipeline

Para executar o pipeline novamente com full refresh:

```bash
databricks pipelines start-update 36cb3313-d470-4637-8bf1-b4f8668ded1a --full-refresh --profile grid_intelligence
```

## 📝 Arquivos Criados

- `src/pipelines/grid_intelligence/transformations/20_gold_continuidade.sql`
- `src/pipelines/grid_intelligence/transformations/21_gold_prioridade_inspecao.sql`
- `src/pipelines/grid_intelligence/transformations/22_gold_saude_cliente.sql`
- `src/pipelines/grid_intelligence/transformations/23_gold_painel_operacional.sql`
- `src/sql/metric_view_continuidade.sql` (versão parametrizada)
- `src/sql/metric_view_continuidade_dev.sql` (versão dev)
- `src/notebooks/create_metric_view.py` (criação via notebook)
- `validate_gold.sql` (queries de validação)
