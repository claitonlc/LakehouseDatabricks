-- Gold: Continuidade do Fornecimento — Insumos para DEC e FEC
--
-- DECISÃO DE ARQUITETURA (RN-04):
-- Esta tabela NÃO calcula DEC nem FEC. Ela guarda os **insumos aditivos**:
-- - uc_horas_interrompidas (numerador do DEC)
-- - uc_interrupcoes (numerador do FEC)
-- - total_ucs (denominador de ambos)
--
-- A **definição** de DEC e FEC vive em um único lugar: a metric view
-- (src/sql/metric_view_continuidade.sql). Separar insumos de definição permite
-- somar qualquer recorte sem risco de duas fórmulas divergirem.
--
-- GRÃO: um registro por (id_conjunto, mes_apuracao)
-- ORIGEM: silver.interrupcoes_validas agregada + silver.unidades_consumidoras para total_ucs

-- ====================================================================================
-- Continuidade por conjunto e mês — os insumos para DEC e FEC
-- ====================================================================================
CREATE OR REFRESH MATERIALIZED VIEW ${catalogo}.${schema_gold}.continuidade_conjunto_mes
COMMENT 'Insumos mensais para cálculo de DEC e FEC por conjunto. Esta tabela não calcula os indicadores finais - apenas armazena os numeradores e denominadores que a metric view usa para garantir definição única (RN-04).'
AS
WITH interrupcoes_agregadas AS (
  SELECT
    i.id_conjunto,
    i.mes_apuracao,
    -- Numeradores de DEC e FEC
    SUM(i.uc_horas_interrompidas) AS uc_horas_interrompidas,
    SUM(i.qtd_ucs_afetadas) AS uc_interrupcoes,
    -- Métricas de contexto
    COUNT(*) AS qtd_interrupcoes,
    SUM(CASE WHEN i.causa_climatica THEN 1 ELSE 0 END) AS qtd_interrupcoes_climaticas,
    SUM(CASE WHEN i.causa = 'programada' THEN 1 ELSE 0 END) AS qtd_interrupcoes_programadas,
    MAX(i.duracao_horas) AS maior_duracao_horas
  FROM ${catalogo}.${schema_silver}.interrupcoes_validas i
  GROUP BY i.id_conjunto, i.mes_apuracao
),
total_ucs_por_conjunto AS (
  SELECT
    id_conjunto,
    COUNT(*) AS total_ucs
  FROM ${catalogo}.${schema_silver}.unidades_consumidoras
  GROUP BY id_conjunto
)
SELECT
  ia.id_conjunto,
  CAST(ia.id_conjunto AS STRING) AS nome_conjunto,
  'Região ' || CAST(ia.id_conjunto AS STRING) AS municipio,
  ia.mes_apuracao,
  tc.total_ucs,
  ia.uc_horas_interrompidas,
  ia.uc_interrupcoes,
  ia.qtd_interrupcoes,
  ia.qtd_interrupcoes_climaticas,
  ia.qtd_interrupcoes_programadas,
  ia.maior_duracao_horas
FROM interrupcoes_agregadas ia
INNER JOIN total_ucs_por_conjunto tc
  ON ia.id_conjunto = tc.id_conjunto;
