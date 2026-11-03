-- ==================================================================================
-- TESTE DE QUERIES DO DASHBOARD AI/BI
-- Execute cada query para validar antes de criar o JSON do dashboard
-- ==================================================================================

-- Catálogo e schema
USE CATALOG grid_dev;
USE SCHEMA gold;

-- ==================================================================================
-- PÁGINA 1: OPERAÇÃO DO DIA
-- ==================================================================================

-- Query 1: KPI - Horas-UC interrompidas (últimos 30 dias para sparkline)
SELECT 
  dia,
  SUM(total_horas_interrupcao) AS horas_uc_interrompidas
FROM painel_operacional_dia
WHERE dia >= DATE_SUB(CURRENT_DATE(), 30)
GROUP BY dia
ORDER BY dia;

-- ==================================================================================

-- Query 2: KPI - Total de chamados (últimos 30 dias para sparkline)
SELECT 
  dia,
  SUM(qtd_chamados_dia) AS total_chamados
FROM painel_operacional_dia
WHERE dia >= DATE_SUB(CURRENT_DATE(), 30)
GROUP BY dia
ORDER BY dia;

-- ==================================================================================

-- Query 3: KPI - Chamados com risco à saúde (últimos 30 dias para sparkline)
SELECT 
  dia,
  SUM(qtd_relatos_risco_saude) AS chamados_risco_saude
FROM painel_operacional_dia
WHERE dia >= DATE_SUB(CURRENT_DATE(), 30)
GROUP BY dia
ORDER BY dia;

-- ==================================================================================

-- Query 4: KPI - UCs em prioridade de inspeção (snapshot atual)
SELECT 
  COUNT(*) AS ucs_inspecao_pendente
FROM prioridade_inspecao_uc
WHERE prioridade_inspecao IN ('alta', 'media');

-- ==================================================================================

-- Query 5: Série temporal - Chamados vs Horas-UC (últimos 30 dias)
SELECT 
  dia,
  SUM(qtd_chamados_dia) AS total_chamados,
  SUM(total_horas_interrupcao) AS horas_uc_interrompidas
FROM painel_operacional_dia
WHERE dia >= DATE_SUB(CURRENT_DATE(), 30)
GROUP BY dia
ORDER BY dia;

-- ==================================================================================

-- Query 6: DEC por conjunto (usando tabela base, não metric view)
-- A metric view com MEASURE() só funciona em Genie/BI tools
SELECT 
  nome_conjunto AS conjunto,
  ROUND(SUM(uc_horas_interrompidas) / SUM(total_ucs), 2) AS dec_horas
FROM continuidade_conjunto_mes
GROUP BY nome_conjunto
ORDER BY dec_horas DESC;

-- ==================================================================================

-- Query 7: Tabela de ações recomendadas (últimos 7 dias)
SELECT 
  nome_conjunto AS conjunto,
  dia,
  acao_recomendada,
  qtd_interrupcoes_dia AS interrupcoes,
  qtd_chamados_dia AS chamados,
  qtd_relatos_risco_saude AS risco_saude,
  qtd_mencoes_ouvidoria AS mencoes_ouvidoria
FROM painel_operacional_dia
WHERE 
  dia >= DATE_SUB(CURRENT_DATE(), 7)
  AND (
    qtd_relatos_risco_saude > 0
    OR qtd_mencoes_ouvidoria > 0
    OR total_ucs_afetadas >= (total_ucs_conjunto * 0.1)
    OR qtd_inspecao_alta >= 5
  )
ORDER BY 
  CASE 
    WHEN qtd_relatos_risco_saude > 0 THEN 1
    WHEN qtd_mencoes_ouvidoria > 0 THEN 2
    WHEN total_ucs_afetadas >= (total_ucs_conjunto * 0.1) THEN 3
    ELSE 4
  END,
  dia DESC;

-- ==================================================================================
-- PÁGINA 2: PERDAS NÃO TÉCNICAS E CLIENTES
-- ==================================================================================

-- Query 8: UCs por bairro e prioridade (barra empilhada)
SELECT 
  bairro,
  prioridade_inspecao,
  COUNT(*) AS qtd_ucs
FROM prioridade_inspecao_uc
GROUP BY bairro, prioridade_inspecao
ORDER BY bairro, prioridade_inspecao;

-- ==================================================================================

-- Query 9: Tabela de detalhe da priorização (top 20)
SELECT 
  id_uc,
  nome_conjunto AS conjunto,
  bairro,
  prioridade_inspecao,
  ROUND(variacao_da_uc, 1) AS variacao_pct,
  ROUND(consumo_medio_baseline_kwh, 1) AS baseline_kwh,
  ROUND(consumo_medio_recente_kwh, 1) AS recente_kwh,
  motivo_observado
FROM prioridade_inspecao_uc
WHERE prioridade_inspecao IN ('alta', 'media')
ORDER BY 
  CASE prioridade_inspecao WHEN 'alta' THEN 1 ELSE 2 END,
  ABS(variacao_da_uc) DESC
LIMIT 20;

-- ==================================================================================

-- Query 10: Clientes em rota de ouvidoria (top 15)
SELECT 
  id_cliente AS cliente,
  nome_conjunto AS conjunto,
  bairro,
  risco_ouvidoria,
  qtd_chamados,
  qtd_mencoes_ouvidoria AS mencoes_ouvidoria,
  qtd_chamados_risco_saude AS risco_saude,
  motivo_predominante,
  SUBSTRING(ultima_fala, 1, 200) AS ultima_fala_resumida,
  ultimo_chamado_em
FROM saude_cliente
WHERE risco_ouvidoria IN ('alto', 'medio')
ORDER BY 
  CASE risco_ouvidoria WHEN 'alto' THEN 1 ELSE 2 END,
  qtd_chamados DESC
LIMIT 15;

-- ==================================================================================
-- ✅ SE TODAS AS 10 QUERIES RODARAM, O DASHBOARD PODE SER CRIADO
-- ==================================================================================
