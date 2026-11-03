-- ==================================================================================
-- VALIDAÇÃO GOLD - Queries SQL Diretas (SEM MEASURE)
-- ==================================================================================
-- Use este arquivo se as queries com MEASURE() não funcionarem
-- Estas queries acessam diretamente as tabelas, não a metric view
-- ==================================================================================

-- Query 1: Listar todas as tabelas gold
SHOW TABLES IN grid_dev.gold;
-- Esperado: Ver 5 objetos incluindo continuidade_metricas

-- ==================================================================================

-- Query 2: DEC e FEC por conjunto (calculado diretamente)
SELECT 
  nome_conjunto AS conjunto,
  ROUND(SUM(uc_horas_interrompidas) / SUM(total_ucs), 3) AS dec_horas,
  ROUND(SUM(uc_interrupcoes) / SUM(total_ucs), 3) AS fec_vezes,
  ROUND(SUM(total_ucs) / COUNT(DISTINCT mes_apuracao), 0) AS base_ucs
FROM grid_dev.gold.continuidade_conjunto_mes
GROUP BY nome_conjunto
ORDER BY nome_conjunto;
-- Esperado: 6 linhas (6 conjuntos), DEC entre 0.05 e 10, FEC entre 0.1 e 15

-- ==================================================================================

-- Query 3: DEC/FEC mensal - ordem de grandeza
SELECT 
  nome_conjunto AS conjunto,
  COUNT(DISTINCT mes_apuracao) AS qtd_meses,
  ROUND(AVG(uc_horas_interrompidas / total_ucs), 3) AS dec_medio_mensal,
  ROUND(MIN(uc_horas_interrompidas / total_ucs), 3) AS dec_minimo,
  ROUND(MAX(uc_horas_interrompidas / total_ucs), 3) AS dec_maximo
FROM grid_dev.gold.continuidade_conjunto_mes
GROUP BY nome_conjunto
ORDER BY nome_conjunto;
-- Esperado: dec_medio_mensal entre 0.05 e 1.5 horas por mês

-- ==================================================================================

-- Query 4: Amostra de dados DEC/FEC (últimos 90 dias ou todos os dados)
SELECT 
  nome_conjunto AS conjunto,
  DATE_FORMAT(mes_apuracao, 'MMM/yyyy') AS mes_formatado,
  ROUND(uc_horas_interrompidas / total_ucs, 2) AS dec_horas,
  ROUND(uc_interrupcoes / total_ucs, 2) AS fec_vezes,
  qtd_interrupcoes AS eventos,
  ROUND(qtd_interrupcoes_climaticas / NULLIF(qtd_interrupcoes, 0) * 100, 1) AS pct_climatico
FROM grid_dev.gold.continuidade_conjunto_mes
WHERE mes_apuracao >= DATE_SUB(CURRENT_DATE(), 90)
ORDER BY mes_apuracao DESC, dec_horas DESC
LIMIT 20;
-- Esperado: Dados recentes com DEC/FEC calculados

-- ==================================================================================

-- Query 5: Se a query acima não trouxer dados, tente SEM filtro de data:
SELECT 
  nome_conjunto AS conjunto,
  DATE_FORMAT(mes_apuracao, 'MMM/yyyy') AS mes_formatado,
  ROUND(uc_horas_interrompidas / total_ucs, 2) AS dec_horas,
  ROUND(uc_interrupcoes / total_ucs, 2) AS fec_vezes,
  qtd_interrupcoes AS eventos,
  total_ucs AS base_ucs
FROM grid_dev.gold.continuidade_conjunto_mes
ORDER BY mes_apuracao DESC, dec_horas DESC
LIMIT 20;
-- Esperado: Ver TODOS os meses disponíveis

-- ==================================================================================

-- Query 6: Contagem de prioridades de inspeção
SELECT 
  prioridade_inspecao,
  COUNT(*) AS qtd_ucs,
  ROUND(AVG(ABS(variacao_da_uc)), 1) AS media_variacao_pct,
  COUNT(DISTINCT id_conjunto) AS qtd_conjuntos
FROM grid_dev.gold.prioridade_inspecao_uc
GROUP BY prioridade_inspecao
ORDER BY CASE prioridade_inspecao WHEN 'alta' THEN 1 WHEN 'media' THEN 2 ELSE 3 END;
-- Esperado: 3 linhas (alta, media, baixa)

-- ==================================================================================

-- Query 7: Verificar que NÃO há palavras proibidas (RN-07)
SELECT COUNT(*) AS tem_palavra_proibida
FROM grid_dev.gold.prioridade_inspecao_uc
WHERE motivo_observado LIKE '%fraude%' 
   OR motivo_observado LIKE '%furto%' 
   OR motivo_observado LIKE '%culpado%';
-- Esperado: 0 (zero linhas com palavras proibidas)

-- ==================================================================================

-- Query 8: Saúde do cliente - distribuição de risco
SELECT 
  risco_ouvidoria,
  COUNT(*) AS qtd_clientes,
  SUM(qtd_chamados) AS total_chamados,
  SUM(qtd_mencoes_ouvidoria) AS mencoes_ouvidoria_aneel,
  ROUND(AVG(qtd_chamados), 1) AS media_chamados_por_cliente
FROM grid_dev.gold.saude_cliente
GROUP BY risco_ouvidoria
ORDER BY CASE risco_ouvidoria WHEN 'alto' THEN 1 WHEN 'medio' THEN 2 ELSE 3 END;
-- Esperado: 3 linhas (alto, medio, baixo)

-- ==================================================================================

-- Query 9: Painel operacional - contagem geral
SELECT 
  COUNT(*) AS total_registros,
  COUNT(DISTINCT id_conjunto) AS qtd_conjuntos,
  COUNT(DISTINCT dia) AS qtd_dias_distintos,
  MIN(dia) AS primeiro_dia,
  MAX(dia) AS ultimo_dia
FROM grid_dev.gold.painel_operacional_dia;
-- Esperado: Centenas de registros, 6 conjuntos, vários dias

-- ==================================================================================

-- Query 10: Tipos de ação recomendada no painel
SELECT 
  SUBSTRING(acao_recomendada, 1, 30) AS tipo_acao,
  COUNT(*) AS qtd_ocorrencias
FROM grid_dev.gold.painel_operacional_dia
GROUP BY SUBSTRING(acao_recomendada, 1, 30)
ORDER BY qtd_ocorrencias DESC
LIMIT 10;
-- Esperado: Ver categorias como CRÍTICO, URGENTE, ROTINA, NORMAL

-- ==================================================================================

-- Query 11: Validar total de interrupções em GOLD
SELECT 
  SUM(qtd_interrupcoes) AS total_gold
FROM grid_dev.gold.continuidade_conjunto_mes;
-- Esperado: 1073

-- ==================================================================================

-- Query 12: Validar total de interrupções em SILVER (deve ser igual)
SELECT 
  COUNT(*) AS total_silver
FROM grid_dev.silver.interrupcoes_validas;
-- Esperado: 1073 (mesmo valor da query anterior)

-- ==================================================================================

-- Query 13: Verificar estrutura da metric view
DESCRIBE TABLE grid_dev.gold.continuidade_metricas;
-- Esperado: Ver a estrutura da view

-- ==================================================================================
-- ✅ SE TODAS AS QUERIES EXECUTARAM E OS VALORES BATEM, ESTÁ TUDO OK!
-- ==================================================================================

