-- ==================================================================================
-- TESTE RÁPIDO - Execute estas 5 queries para confirmar que está tudo OK
-- ==================================================================================

-- 1️⃣ TESTE: A metric view foi criada?
SELECT 'Metric View Criada!' AS status, COUNT(*) AS qtd_registros
FROM grid_dev.gold.continuidade_metricas;

-- 2️⃣ TESTE: DEC e FEC estão calculando corretamente?
SELECT 
  `Conjunto`,
  ROUND(MEASURE(`DEC`), 3) AS dec_horas,
  ROUND(MEASURE(`FEC`), 3) AS fec_vezes,
  MEASURE(`Total de UCs`) AS base_ucs
FROM grid_dev.gold.continuidade_metricas
GROUP BY `Conjunto`
ORDER BY `Conjunto`
LIMIT 10;

-- 3️⃣ TESTE: Prioridades de inspeção estão funcionando?
SELECT 
  prioridade_inspecao,
  COUNT(*) AS qtd_ucs,
  ROUND(AVG(ABS(variacao_da_uc)), 1) AS media_variacao_pct
FROM grid_dev.gold.prioridade_inspecao_uc
GROUP BY prioridade_inspecao
ORDER BY CASE prioridade_inspecao WHEN 'alta' THEN 1 WHEN 'media' THEN 2 ELSE 3 END;

-- 4️⃣ TESTE: Saúde do cliente está classificando risco?
SELECT 
  risco_ouvidoria,
  COUNT(*) AS qtd_clientes,
  SUM(qtd_chamados) AS total_chamados,
  SUM(qtd_mencoes_ouvidoria) AS total_mencoes_ouvidoria
FROM grid_dev.gold.saude_cliente
GROUP BY risco_ouvidoria
ORDER BY CASE risco_ouvidoria WHEN 'alto' THEN 1 WHEN 'medio' THEN 2 ELSE 3 END;

-- 5️⃣ TESTE: Painel operacional tem ações recomendadas?
SELECT 
  SUBSTRING(acao_recomendada, 1, 50) AS tipo_acao,
  COUNT(*) AS qtd_dias
FROM grid_dev.gold.painel_operacional_dia
GROUP BY SUBSTRING(acao_recomendada, 1, 50)
ORDER BY qtd_dias DESC
LIMIT 10;

-- ==================================================================================
-- ✅ SE TODAS AS 5 QUERIES RETORNARAM RESULTADOS, ESTÁ TUDO OK! 🎉
-- ==================================================================================
