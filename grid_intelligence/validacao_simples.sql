-- ==================================================================================
-- VALIDAÇÃO SIMPLES - Execute query por query (não todas de uma vez)
-- ==================================================================================

-- Query 1: Listar todas as tabelas gold
SHOW TABLES IN grid_dev.gold;
-- Esperado: Ver 5 objetos incluindo continuidade_metricas

-- ==================================================================================

-- Query 2: Testar metric view - DEC e FEC por conjunto
SELECT 
  `Conjunto`,
  ROUND(MEASURE(`DEC`), 3) AS dec_horas,
  ROUND(MEASURE(`FEC`), 3) AS fec_vezes,
  MEASURE(`Total de UCs`) AS base_ucs
FROM grid_dev.gold.continuidade_metricas
GROUP BY `Conjunto`
ORDER BY `Conjunto`;
-- Esperado: 6 linhas (6 conjuntos), DEC entre 0.05 e 10, FEC entre 0.1 e 15

-- ==================================================================================

-- Query 3: Ordem de grandeza DEC/FEC mensal vs acumulado
SELECT 
  `Conjunto`,
  COUNT(DISTINCT `Mes`) AS qtd_meses,
  ROUND(AVG(MEASURE(`DEC`)), 3) AS dec_medio_mensal,
  ROUND(MIN(MEASURE(`DEC`)), 3) AS dec_minimo,
  ROUND(MAX(MEASURE(`DEC`)), 3) AS dec_maximo
FROM grid_dev.gold.continuidade_metricas
GROUP BY `Conjunto`
ORDER BY `Conjunto`;
-- Esperado: dec_medio_mensal entre 0.05 e 1.5 horas por mês

-- ==================================================================================

-- Query 4: Contagem de prioridades de inspeção
SELECT 
  prioridade_inspecao,
  COUNT(*) AS qtd_ucs,
  ROUND(AVG(ABS(variacao_da_uc)), 1) AS media_variacao_pct
FROM grid_dev.gold.prioridade_inspecao_uc
GROUP BY prioridade_inspecao
ORDER BY CASE prioridade_inspecao WHEN 'alta' THEN 1 WHEN 'media' THEN 2 ELSE 3 END;
-- Esperado: 3 linhas (alta, media, baixa)

-- ==================================================================================

-- Query 5: Verificar que NÃO há palavras proibidas (RN-07)
SELECT COUNT(*) AS tem_palavra_proibida
FROM grid_dev.gold.prioridade_inspecao_uc
WHERE motivo_observado LIKE '%fraude%' 
   OR motivo_observado LIKE '%furto%' 
   OR motivo_observado LIKE '%culpado%';
-- Esperado: 0 (zero linhas com palavras proibidas)

-- ==================================================================================

-- Query 6: Saúde do cliente - distribuição de risco
SELECT 
  risco_ouvidoria,
  COUNT(*) AS qtd_clientes,
  SUM(qtd_chamados) AS total_chamados,
  SUM(qtd_mencoes_ouvidoria) AS mencoes_ouvidoria_aneel
FROM grid_dev.gold.saude_cliente
GROUP BY risco_ouvidoria
ORDER BY CASE risco_ouvidoria WHEN 'alto' THEN 1 WHEN 'medio' THEN 2 ELSE 3 END;
-- Esperado: 3 linhas (alto, medio, baixo)

-- ==================================================================================

-- Query 7: Painel operacional - contagem geral
SELECT 
  COUNT(*) AS total_registros,
  COUNT(DISTINCT id_conjunto) AS qtd_conjuntos,
  COUNT(DISTINCT dia) AS qtd_dias_distintos,
  MIN(dia) AS primeiro_dia,
  MAX(dia) AS ultimo_dia
FROM grid_dev.gold.painel_operacional_dia;
-- Esperado: Centenas de registros, 6 conjuntos, vários dias

-- ==================================================================================

-- Query 8: Tipos de ação recomendada no painel
SELECT 
  SUBSTRING(acao_recomendada, 1, 20) AS tipo_acao,
  COUNT(*) AS qtd_ocorrencias
FROM grid_dev.gold.painel_operacional_dia
GROUP BY SUBSTRING(acao_recomendada, 1, 20)
ORDER BY qtd_ocorrencias DESC
LIMIT 10;
-- Esperado: Ver categorias como CRÍTICO, URGENTE, ROTINA, NORMAL

-- ==================================================================================

-- Query 9: Validar total de interrupções (deve ser igual em todas camadas)
SELECT 
  SUM(qtd_interrupcoes) AS total_gold_tabela
FROM grid_dev.gold.continuidade_conjunto_mes;
-- Esperado: 1073

SELECT 
  COUNT(*) AS total_silver
FROM grid_dev.silver.interrupcoes_validas;
-- Esperado: 1073 (mesmo valor da query anterior)

-- ==================================================================================

-- Query 10: Exemplo de uso da metric view para dashboard
SELECT 
  `Conjunto`,
  DATE_FORMAT(`Mes`, 'MMM/yyyy') AS mes_formatado,
  ROUND(MEASURE(`DEC`), 2) AS dec_horas,
  ROUND(MEASURE(`FEC`), 2) AS fec_vezes,
  MEASURE(`Interrupcoes`) AS eventos,
  ROUND(MEASURE(`Proporcao Climatica`) * 100, 1) AS pct_climatico
FROM grid_dev.gold.continuidade_metricas
WHERE `Mes` >= DATE_SUB(CURRENT_DATE(), 90)
GROUP BY `Conjunto`, `Mes`
ORDER BY `Mes` DESC, MEASURE(`DEC`) DESC
LIMIT 20;
-- Esperado: Últimos 3 meses de dados, valores legíveis

-- ==================================================================================
-- ✅ SE TODAS AS 10 QUERIES EXECUTARAM SEM ERRO, ESTÁ TUDO OK!
-- ==================================================================================
