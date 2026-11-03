-- Silver: Interrupções Válidas — RN-01
--
-- Somente interrupções de fornecimento com duração >= 3 minutos entram na apuração
-- dos indicadores de continuidade (DEC e FEC).
--
-- Eventos abaixo de 3 minutos são religadores automáticos atuando: galho na rede,
-- desarme e religamento em segundos. O consumidor vê a luz piscar; não é falta.
-- No dataset são 310 de 1.383 eventos (22,4%) que são descartados aqui.

CREATE OR REFRESH STREAMING TABLE ${catalogo}.${schema_silver}.interrupcoes_validas
TBLPROPERTIES ('delta.feature.timestampNtz' = 'supported')
AS SELECT
  id_interrupcao,
  id_conjunto,
  inicio,
  duracao_minutos,
  qtd_ucs_afetadas,
  causa,
  -- Colunas derivadas que preparam os insumos para DEC e FEC
  to_date(inicio) AS data_evento,
  date_trunc('MONTH', inicio) AS mes_apuracao,
  duracao_minutos / 60.0 AS duracao_horas,
  (duracao_minutos / 60.0) * qtd_ucs_afetadas AS uc_horas_interrompidas,  -- numerador do DEC
  causa = 'climatica' AS causa_climatica
FROM STREAM(${catalogo}.${schema_bronze}.interrupcoes)
WHERE duracao_minutos >= ${duracao_minima_interrupcao_min};
