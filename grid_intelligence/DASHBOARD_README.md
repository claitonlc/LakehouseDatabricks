# Dashboard Grid Intelligence - Documentação

## Visão Geral

Dashboard AI/BI (Lakeview) de 2 páginas para visualização executiva da operação diária e análise de perdas não técnicas da Luz do Vale Distribuidora.

**Nome:** `[dev] Grid Intelligence - Operação e Perdas`
**Localização:** `/Workspace/Users/claitonlc@gmail.com/dashboards/`
**Warehouse:** da15f79585892515 (Serverless Starter Warehouse)

## Estrutura do Dashboard

### Página 1: Operação do Dia

Visão executiva para o gestor de operações começar o dia em 2 minutos.

**Widgets:**

1. **KPI - Horas-UC Interrompidas** (com sparkline)
   - Total de horas-unidade consumidora sem fornecimento
   - Sparkline dos últimos 90 dias mostra tendência

2. **KPI - Total de Chamados** (com sparkline)
   - Chamados registrados no call center
   - Sparkline dos últimos 90 dias

3. **KPI - Chamados Risco à Saúde** (com sparkline)
   - Relatos de clientes com equipamentos médicos dependentes de energia
   - Sparkline dos últimos 90 dias

4. **KPI - UCs Prioridade Inspeção**
   - Snapshot atual de UCs com prioridade alta/média de inspeção

5. **Série Temporal - Chamados vs Horas-UC**
   - Gráfico de linhas cruzando as duas métricas principais
   - Mostra a correlação entre picos de interrupção e volume de chamados
   - Janela: últimos 90 dias

6. **Barra Horizontal - DEC por Conjunto**
   - Duração Equivalente de Interrupção por conjunto
   - Calcula DEC diretamente da tabela `continuidade_conjunto_mes` (RN-04)
   - Ordenado por DEC decrescente para destacar conjuntos problemáticos

7. **Tabela - Ações Recomendadas**
   - Últimos 7 dias de eventos críticos
   - Filtrada para mostrar apenas:
     - Relatos de risco à saúde (CRÍTICO)
     - Menções a ouvidoria/ANEEL (URGENTE)
     - Impacto grande na rede (ALTO IMPACTO)
   - Colunas: Conjunto, Data, Ação Recomendada, Interrupções, Chamados

### Página 2: Perdas Não Técnicas e Clientes

Análise de prioridades de inspeção e clientes em rota de ouvidoria.

**Widgets:**

1. **Texto - Aviso RN-07**
   - **IMPORTANTE:** Explica que a classificação é prioridade de inspeção, não acusação
   - Lista causas alternativas para queda de consumo:
     - Mudança de morador / imóvel desocupado
     - Defeito no medidor / erro de leitura
     - Mudança no padrão de uso
     - Irregularidade (requer confirmação no local)
   - Reforça que nenhuma ação punitiva deve ser tomada sem visita técnica

2. **Barra Empilhada - UCs por Bairro e Prioridade**
   - Distribuição de UCs candidatas a inspeção por bairro
   - Empilhamento por prioridade (alta/média/baixa)
   - Cores:
     - Alta: #E85D75 (coral quente)
     - Média: #F4C430 (amarelo)
     - Baixa: #90EE90 (verde claro)
   - Concentração em único bairro com conjunto estável é o padrão que RN-06 procura

3. **Tabela - Detalhamento da Priorização**
   - Top 20 UCs com prioridade alta/média
   - Colunas:
     - UC, Conjunto, Bairro, Prioridade
     - Variação % (da UC contra baseline)
     - Baseline kWh, Recente kWh
     - Motivo Observado (texto explicativo)
   - Ordenado por: prioridade (alta primeiro), depois por magnitude da variação

4. **Tabela - Clientes em Rota de Ouvidoria**
   - Top 15 clientes com risco alto/médio
   - Colunas:
     - Cliente, Conjunto, Bairro, Risco
     - Chamados, Menções Ouvidoria, Risco Saúde
     - Motivo predominante
     - Última Fala (primeiros 150 chars, já anonimizada)
   - Ordenado por: risco (alto primeiro), depois por qtd de chamados
   - Nota: Textos já passaram por processo de anonimização (RN-09)

## Datasets e Queries

### Dataset 1: ds_painel_operacional
```sql
SELECT * FROM painel_operacional_dia
WHERE dia >= DATE_SUB(CURRENT_DATE(), 90)
ORDER BY dia DESC
```

### Dataset 2: ds_continuidade
```sql
SELECT nome_conjunto,
       ROUND(SUM(uc_horas_interrompidas) / SUM(total_ucs), 2) AS dec_horas
FROM continuidade_conjunto_mes
GROUP BY nome_conjunto
```

### Dataset 3: ds_prioridade
```sql
SELECT * FROM prioridade_inspecao_uc
WHERE prioridade_inspecao IN ('alta', 'media')
```

### Dataset 4: ds_saude_cliente
```sql
SELECT * FROM saude_cliente
WHERE risco_ouvidoria IN ('alto', 'medio')
```

## Regras de Negócio Implementadas

- **RN-04:** DEC calculado a partir dos insumos em `continuidade_conjunto_mes` (definição única)
- **RN-06:** Priorização por dois eixos (UC cai + vizinhança estável)
- **RN-07:** Linguagem de priorização, não acusação (aviso explícito na página 2)
- **RN-09:** Textos já anonimizados antes de exibição
- **RN-14:** Descrições em linguagem de negócio nas tabelas gold

## Como Acessar

1. **Via Databricks UI:**
   - Navegue para o workspace: https://dbc-2e4f52fb-96e3.cloud.databricks.com
   - Acesse: `SQL` → `Dashboards` → `[dev] Grid Intelligence - Operação e Perdas`

2. **Via CLI:**
   ```bash
   databricks workspace list "/Workspace/Users/claitonlc@gmail.com/dashboards" --profile grid_intelligence
   ```

3. **Via Bundle:**
   O dashboard é gerenciado como recurso no bundle:
   ```bash
   cd grid_intelligence
   databricks bundle deploy --profile grid_intelligence
   ```

## Arquivos do Dashboard

- **JSON:** `resources/grid_dashboard.json` - Definição completa do dashboard
- **YAML:** `resources/grid_dashboard.yml` - Recurso do bundle
- **Queries de Teste:** `test_dashboard_queries.sql` - 10 queries para validação manual

## Troubleshooting

### Dashboard não carrega dados
- Verifique se o pipeline gold está com status COMPLETED:
  ```bash
  databricks pipelines get 36cb3313-d470-4637-8bf1-b4f8668ded1a --profile grid_intelligence
  ```
- Confirme que as tabelas gold existem:
  ```sql
  SHOW TABLES IN grid_dev.gold;
  ```

### Erro "warehouse not found"
- Verifique se o warehouse está ativo:
  ```bash
  databricks warehouses get da15f79585892515 --profile grid_intelligence
  ```
- Se necessário, inicie o warehouse (Serverless inicia automaticamente na primeira query)

### Widget mostra "No data"
- Execute a query do dataset manualmente via SQL Editor
- Verifique se há filtros que estão excluindo todos os dados
- Confirme a janela temporal dos dados (ex: dataset usa CURRENT_DATE(), dados podem estar no passado)

## Próximos Passos

Conforme o prompt 05-dashboard.md, após validar o dashboard:

1. ✅ Todas queries rodam sem erro
2. ✅ DEC vem da tabela base (não de MEASURE(), pois não funciona em SQL direto)
3. ✅ Nenhum nome de catálogo fixado no JSON (usa `dataset` names)
4. ✅ Página 2 avisa que é prioridade, não acusação
5. ✅ Dashboard abre e widgets renderizam

**Próximo prompt:** 06-agente.md - Criar agente conversacional em português
