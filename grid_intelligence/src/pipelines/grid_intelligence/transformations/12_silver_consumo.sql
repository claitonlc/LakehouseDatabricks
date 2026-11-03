-- Silver: Consumo Diário e Baseline
--
-- Duas materialized views (não streaming, pois dedup e baseline exigem batch):
-- 1. consumo_diario: descarte de leituras inválidas, deduplicação, join com cadastro
-- 2. baseline_consumo: janelas de 30 e 90 dias para detecção de perdas (RN-06)

-- ====================================================================================
-- 1. consumo_diario: limpeza e deduplicação
-- ====================================================================================
CREATE OR REFRESH MATERIALIZED VIEW ${catalogo}.${schema_silver}.consumo_diario
AS
SELECT
  c.id_uc,
  c.data,
  c.consumo_kwh,
  c.ingerido_bronze_em,
  -- Join com cadastro para as regras de perdas não refazerem esse join
  uc.id_conjunto,
  uc.bairro,
  uc.classe_consumo
FROM ${catalogo}.${schema_bronze}.consumo_diario c
INNER JOIN ${catalogo}.${schema_silver}.unidades_consumidoras uc
  ON c.id_uc = uc.id_uc
WHERE 
  -- Descarta leituras inválidas
  consumo_kwh IS NOT NULL
  AND consumo_kwh > 0
  AND consumo_kwh <= CASE 
    WHEN uc.classe_consumo = 'residencial' THEN 500
    WHEN uc.classe_consumo = 'comercial' THEN 2000
    WHEN uc.classe_consumo = 'industrial' THEN 10000
    ELSE 1000
  END
QUALIFY row_number() OVER (PARTITION BY c.id_uc, c.data ORDER BY c.ingerido_bronze_em DESC) = 1;

-- ====================================================================================
-- 2. baseline_consumo: janelas para detecção de perdas (RN-06)
-- ====================================================================================
-- Baseline sobre série com tendência precisa de janela comparável.
-- Comparar últimos 30 dias contra toda a série acusa alta de 50%+ em todas as UCs
-- (crescimento de 30% a.a. em 4 anos). Resultado: segundo eixo da RN-06 para de funcionar.
--
-- Solução: 90 dias imediatamente anteriores aos últimos 30. Carrega ~4% de crescimento
-- entre os centros das janelas — ruído pequeno o suficiente para a faixa de estabilidade.

CREATE OR REFRESH MATERIALIZED VIEW ${catalogo}.${schema_silver}.baseline_consumo
AS
WITH parametros AS (
  SELECT
    max(data) AS data_maxima
  FROM ${catalogo}.${schema_silver}.consumo_diario
),
janelas AS (
  SELECT
    data_maxima,
    date_sub(data_maxima, 29) AS inicio_recente,
    date_sub(data_maxima, 30) AS fim_baseline,
    date_sub(data_maxima, 119) AS inicio_baseline
  FROM parametros
),
consumo_por_uc AS (
  SELECT
    c.id_uc,
    c.id_conjunto,
    avg(CASE WHEN c.data BETWEEN j.inicio_baseline AND j.fim_baseline 
             THEN c.consumo_kwh END) AS media_baseline,
    count(CASE WHEN c.data BETWEEN j.inicio_baseline AND j.fim_baseline 
               THEN 1 END) AS dias_baseline,
    avg(CASE WHEN c.data >= j.inicio_recente 
             THEN c.consumo_kwh END) AS media_recente,
    count(CASE WHEN c.data >= j.inicio_recente 
               THEN 1 END) AS dias_recente
  FROM ${catalogo}.${schema_silver}.consumo_diario c
  CROSS JOIN janelas j
  WHERE c.data >= j.inicio_baseline
  GROUP BY c.id_uc, c.id_conjunto
),
consumo_por_conjunto AS (
  SELECT
    id_conjunto,
    avg(media_baseline) AS media_baseline_conjunto,
    avg(media_recente) AS media_recente_conjunto
  FROM consumo_por_uc
  GROUP BY id_conjunto
)
SELECT
  uc.id_uc,
  uc.id_conjunto,
  uc.media_baseline,
  uc.media_recente,
  uc.dias_baseline,
  uc.dias_recente,
  CASE 
    WHEN uc.media_baseline > 0 
    THEN 100.0 * (uc.media_recente - uc.media_baseline) / uc.media_baseline
    ELSE NULL
  END AS variacao_pct,
  cj.media_baseline_conjunto,
  cj.media_recente_conjunto,
  CASE 
    WHEN cj.media_baseline_conjunto > 0 
    THEN 100.0 * (cj.media_recente_conjunto - cj.media_baseline_conjunto) / cj.media_baseline_conjunto
    ELSE NULL
  END AS variacao_conjunto_pct
FROM consumo_por_uc uc
INNER JOIN consumo_por_conjunto cj
  ON uc.id_conjunto = cj.id_conjunto;
