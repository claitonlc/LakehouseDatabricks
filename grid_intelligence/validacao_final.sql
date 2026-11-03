-- ==================================================================================
-- VALIDAÇÃO FINAL DA CAMADA GOLD
-- Execute estas queries no Databricks SQL Editor para verificar que tudo está OK
-- ==================================================================================

-- 1. Verificar se a metric view existe
SHOW TABLES IN grid_dev.gold LIKE 'continuidade_metricas';

-- 2. Verificar estrutura da metric view (dimensões e medidas)
DESCRIBE TABLE grid_dev.gold.continuidade_metricas;

-- ==================================================================================
-- 3. VALIDAÇÃO DE DEC E FEC - Teste da Metric View
-- ==================================================================================
SELECT 
  `Conjunto`,
  `Mes`,
  MEASURE(`DEC`) AS dec_horas,
  MEASURE(`FEC`) AS fec_ocorrencias,
  MEASURE(`Interrupcoes`) AS total_interrupcoes,
  MEASURE(`Total de UCs`) AS base_ucs
FROM grid_dev.gold.continuidade_metricas
GROUP BY `Conjunto`, `Mes`
ORDER BY `Mes` DESC, `Conjunto`
LIMIT 20;

-- ==================================================================================
-- 4. VERIFICAR ORDEM DE GRANDEZA (Critério de Aceite)
-- ==================================================================================
-- Esperado: DEC mensal entre 0.03 e 1.3 horas
-- Se DEC vier em dezenas/centenas, o denominador está errado
SELECT 
  `Conjunto`,
  COUNT(DISTINCT `Mes`) AS qtd_meses,
  ROUND(AVG(MEASURE(`DEC`)), 3) AS dec_medio_mensal,
  ROUND(MIN(MEASURE(`DEC`)), 3) AS dec_minimo,
  ROUND(MAX(MEASURE(`DEC`)), 3) AS dec_maximo,
  ROUND(AVG(MEASURE(`FEC`)), 3) AS fec_medio_mensal
FROM grid_dev.gold.continuidade_metricas
GROUP BY `Conjunto`
ORDER BY `Conjunto`;

-- ==================================================================================
-- 5. TESTE DE DEC ACUMULADO VS DEC MENSAL (Devem ter fórmulas diferentes)
-- ==================================================================================
-- Pegando últimos 3 meses de um conjunto para ver a diferença
SELECT 
  `Conjunto`,
  SUM(MEASURE(`Interrupcoes`)) AS total_interrupcoes,
  ROUND(AVG(MEASURE(`DEC`)), 3) AS dec_media_mensal,
  ROUND(MEASURE(`DEC Acumulado`), 3) AS dec_acumulado_3meses,
  ROUND(AVG(MEASURE(`FEC`)), 3) AS fec_media_mensal
FROM grid_dev.gold.continuidade_metricas
WHERE `Mes` >= DATE_SUB(CURRENT_DATE(), 90)
GROUP BY `Conjunto`;

-- ==================================================================================
-- 6. VALIDAR CONTAGEM TOTAL DE INTERRUPÇÕES (Deve bater com silver)
-- ==================================================================================
-- Esperado: 1.073 interrupções válidas no total
SELECT 
  'Metric View' AS origem,
  SUM(MEASURE(`Interrupcoes`)) AS total_interrupcoes
FROM grid_dev.gold.continuidade_metricas
UNION ALL
SELECT 
  'Tabela Gold' AS origem,
  SUM(qtd_interrupcoes) AS total_interrupcoes
FROM grid_dev.gold.continuidade_conjunto_mes
UNION ALL
SELECT
  'Silver (Fonte)' AS origem,
  COUNT(*) AS total_interrupcoes
FROM grid_dev.silver.interrupcoes_validas;

-- ==================================================================================
-- 7. VERIFICAR PRIORIDADES DE INSPEÇÃO
-- ==================================================================================
SELECT 
  'Prioridade de Inspeção' AS validacao,
  COUNT(*) AS total_registros,
  COUNT(DISTINCT id_uc) AS qtd_ucs_unicas,
  SUM(CASE WHEN prioridade_inspecao = 'alta' THEN 1 ELSE 0 END) AS qtd_alta,
  SUM(CASE WHEN prioridade_inspecao = 'media' THEN 1 ELSE 0 END) AS qtd_media,
  SUM(CASE WHEN prioridade_inspecao = 'baixa' THEN 1 ELSE 0 END) AS qtd_baixa
FROM grid_dev.gold.prioridade_inspecao_uc;

-- ==================================================================================
-- 8. VERIFICAR SAÚDE DO CLIENTE
-- ==================================================================================
SELECT 
  'Saúde do Cliente' AS validacao,
  COUNT(*) AS total_clientes,
  SUM(CASE WHEN risco_ouvidoria = 'alto' THEN 1 ELSE 0 END) AS risco_alto,
  SUM(CASE WHEN risco_ouvidoria = 'medio' THEN 1 ELSE 0 END) AS risco_medio,
  SUM(CASE WHEN risco_ouvidoria = 'baixo' THEN 1 ELSE 0 END) AS risco_baixo,
  SUM(qtd_chamados) AS total_chamados,
  SUM(qtd_mencoes_ouvidoria) AS total_mencoes_ouvidoria
FROM grid_dev.gold.saude_cliente;

-- ==================================================================================
-- 9. VERIFICAR PAINEL OPERACIONAL
-- ==================================================================================
SELECT 
  'Painel Operacional' AS validacao,
  COUNT(*) AS total_registros,
  COUNT(DISTINCT id_conjunto) AS qtd_conjuntos,
  COUNT(DISTINCT dia) AS qtd_dias_distintos,
  MIN(dia) AS primeiro_dia,
  MAX(dia) AS ultimo_dia
FROM grid_dev.gold.painel_operacional_dia;

-- ==================================================================================
-- 10. TESTE DE AÇÃO RECOMENDADA NO PAINEL
-- ==================================================================================
SELECT 
  dia,
  id_conjunto,
  qtd_interrupcoes_dia,
  qtd_chamados_dia,
  qtd_relatos_risco_saude,
  qtd_mencoes_ouvidoria,
  SUBSTRING(acao_recomendada, 1, 100) AS acao_resumida
FROM grid_dev.gold.painel_operacional_dia
WHERE dia >= DATE_SUB(CURRENT_DATE(), 30)
ORDER BY dia DESC
LIMIT 20;

-- ==================================================================================
-- 11. VALIDAÇÃO FINAL - TODAS AS TABELAS GOLD EXISTEM?
-- ==================================================================================
SHOW TABLES IN grid_dev.gold;

-- ==================================================================================
-- 12. EXEMPLO DE USO DA METRIC VIEW PARA DASHBOARD
-- ==================================================================================
-- Como um dashboard ou agente consultaria a metric view
SELECT 
  `Conjunto`,
  `Municipio`,
  DATE_FORMAT(`Mes`, 'MMM/yyyy') AS mes_formatado,
  MEASURE(`DEC`) AS dec_horas,
  MEASURE(`FEC`) AS fec_vezes,
  MEASURE(`Interrupcoes`) AS eventos,
  MEASURE(`Interrupcoes Climaticas`) AS eventos_clima,
  MEASURE(`Proporcao Climatica`) AS pct_climatico,
  CASE 
    WHEN MEASURE(`DEC`) > 1.0 THEN '⚠️ Acima do esperado'
    WHEN MEASURE(`DEC`) > 0.5 THEN '⚡ Atenção'
    ELSE '✅ Normal'
  END AS status
FROM grid_dev.gold.continuidade_metricas
WHERE `Mes` >= DATE_SUB(CURRENT_DATE(), 180)  -- Últimos 6 meses
GROUP BY `Conjunto`, `Municipio`, `Mes`
ORDER BY `Mes` DESC, MEASURE(`DEC`) DESC;
