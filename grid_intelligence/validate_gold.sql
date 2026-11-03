-- Validação das Tabelas Gold
-- Execute este arquivo via databricks labs ucx ou direto no SQL Editor do Databricks

-- 1. Listar tabelas criadas no schema gold
SHOW TABLES IN grid_dev.gold;

-- 2. Verificar contagem da tabela continuidade_conjunto_mes
SELECT 
  'continuidade_conjunto_mes' AS tabela,
  COUNT(*) AS total_registros,
  COUNT(DISTINCT id_conjunto) AS qtd_conjuntos,
  COUNT(DISTINCT mes_apuracao) AS qtd_meses
FROM grid_dev.gold.continuidade_conjunto_mes;

-- 3. Verificar contagem da tabela prioridade_inspecao_uc
SELECT 
  'prioridade_inspecao_uc' AS tabela,
  COUNT(*) AS total_registros,
  COUNT(DISTINCT id_uc) AS qtd_ucs,
  SUM(CASE WHEN prioridade_inspecao = 'alta' THEN 1 ELSE 0 END) AS qtd_alta,
  SUM(CASE WHEN prioridade_inspecao = 'media' THEN 1 ELSE 0 END) AS qtd_media,
  SUM(CASE WHEN prioridade_inspecao = 'baixa' THEN 1 ELSE 0 END) AS qtd_baixa
FROM grid_dev.gold.prioridade_inspecao_uc;

-- 4. Verificar contagem da tabela saude_cliente
SELECT 
  'saude_cliente' AS tabela,
  COUNT(*) AS total_registros,
  SUM(CASE WHEN risco_ouvidoria = 'alto' THEN 1 ELSE 0 END) AS qtd_alto,
  SUM(CASE WHEN risco_ouvidoria = 'medio' THEN 1 ELSE 0 END) AS qtd_medio,
  SUM(CASE WHEN risco_ouvidoria = 'baixo' THEN 1 ELSE 0 END) AS qtd_baixo
FROM grid_dev.gold.saude_cliente;

-- 5. Verificar contagem da tabela painel_operacional_dia
SELECT 
  'painel_operacional_dia' AS tabela,
  COUNT(*) AS total_registros,
  COUNT(DISTINCT id_conjunto) AS qtd_conjuntos,
  COUNT(DISTINCT dia) AS qtd_dias,
  MIN(dia) AS primeiro_dia,
  MAX(dia) AS ultimo_dia
FROM grid_dev.gold.painel_operacional_dia;

-- 6. Validar DEC e FEC via metric view (exemplo com último mês)
-- Esta query testa se a metric view está acessível
SELECT 
  `Conjunto`,
  `Mes`,
  MEASURE(`DEC`) AS dec_horas,
  MEASURE(`FEC`) AS fec_ocorrencias,
  MEASURE(`Interrupcoes`) AS total_interrupcoes
FROM grid_dev.gold.continuidade_metricas
WHERE `Mes` >= DATE_SUB(CURRENT_DATE(), 60)
GROUP BY `Conjunto`, `Mes`
ORDER BY `Mes` DESC, `Conjunto`
LIMIT 10;
