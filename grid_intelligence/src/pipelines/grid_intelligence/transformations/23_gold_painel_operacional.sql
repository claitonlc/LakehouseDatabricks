-- Gold: Painel Operacional Diário — Visão Integrada para Gestão
--
-- DECISÃO DE MODELAGEM:
-- FULL OUTER JOIN separado das 5 origens, não um join único. Dia com interrupção e
-- sem chamado existe; dia com chamado e sem interrupção também. Join comum comeria
-- essas linhas justamente nos dias em que o gestor mais quer olhar.
--
-- COLUNA acao_recomendada:
-- Prioridade na ordem em que um gestor de operações pensaria:
-- 1. Gente em risco à saúde (oxigênio, diálise, etc) — urgência máxima
-- 2. Cliente ameaçando ouvidoria/ANEEL — prevenir escalação
-- 3. Impacto grande na rede (muitas UCs, longa duração) — compensação financeira
-- 4. UCs candidatas a inspeção — investigação preventiva
-- 5. Demais situações — monitoramento de rotina
--
-- GRÃO: um registro por (id_conjunto, dia)
-- ORIGENS: 
-- - silver.interrupcoes_validas
-- - silver.chamados_enriquecidos  
-- - silver.consumo_diario
-- - gold.prioridade_inspecao_uc (única gold que lê outra gold)
-- - silver.unidades_consumidoras

-- ====================================================================================
-- Painel Operacional por Conjunto e Dia
-- ====================================================================================
CREATE OR REFRESH MATERIALIZED VIEW ${catalogo}.${schema_gold}.painel_operacional_dia
COMMENT 'Painel executivo diário integrando interrupções, chamados, consumo e prioridades de inspeção. Fornece visão consolidada para decisão operacional com ações recomendadas priorizadas: risco à saúde, ameaça de ouvidoria, impacto na rede e inspeções preventivas.'
AS
WITH 
-- 1. Agregação de interrupções por conjunto e dia
interrupcoes_dia AS (
  SELECT
    id_conjunto,
    data_evento AS dia,
    COUNT(*) AS qtd_interrupcoes_dia,
    SUM(qtd_ucs_afetadas) AS total_ucs_afetadas,
    SUM(duracao_horas) AS total_horas_interrupcao,
    MAX(duracao_horas) AS maior_interrupcao_horas,
    SUM(CASE WHEN causa_climatica THEN 1 ELSE 0 END) AS qtd_interrupcoes_climaticas
  FROM ${catalogo}.${schema_silver}.interrupcoes_validas
  GROUP BY id_conjunto, data_evento
),
-- 2. Agregação de chamados por conjunto e dia
chamados_dia AS (
  SELECT
    id_conjunto,
    data_chamado AS dia,
    COUNT(*) AS qtd_chamados_dia,
    SUM(CASE WHEN sentimento = 'negative' THEN 1 ELSE 0 END) AS qtd_chamados_negativos,
    SUM(CASE WHEN ameacou_ouvidoria THEN 1 ELSE 0 END) AS qtd_mencoes_ouvidoria,
    SUM(CASE WHEN risco_a_saude THEN 1 ELSE 0 END) AS qtd_relatos_risco_saude,
    SUM(CASE WHEN urgencia = 'alta' THEN 1 ELSE 0 END) AS qtd_chamados_urgencia_alta,
    MODE(motivo) AS motivo_predominante_dia
  FROM ${catalogo}.${schema_silver}.chamados_enriquecidos
  GROUP BY id_conjunto, data_chamado
),
-- 3. Agregação de consumo por conjunto e dia
consumo_dia AS (
  SELECT
    id_conjunto,
    data AS dia,
    COUNT(DISTINCT id_uc) AS qtd_ucs_com_leitura,
    AVG(consumo_kwh) AS consumo_medio_dia_kwh,
    SUM(consumo_kwh) AS consumo_total_dia_kwh,
    STDDEV(consumo_kwh) AS desvio_padrao_consumo
  FROM ${catalogo}.${schema_silver}.consumo_diario
  GROUP BY id_conjunto, data
),
-- 4. Agregação de prioridades de inspeção por conjunto (não tem dimensão de dia)
inspecoes_pendentes AS (
  SELECT
    id_conjunto,
    COUNT(*) AS qtd_ucs_inspecao_pendente,
    SUM(CASE WHEN prioridade_inspecao = 'alta' THEN 1 ELSE 0 END) AS qtd_prioridade_alta,
    SUM(CASE WHEN prioridade_inspecao = 'media' THEN 1 ELSE 0 END) AS qtd_prioridade_media,
    SUM(CASE WHEN prioridade_inspecao = 'baixa' THEN 1 ELSE 0 END) AS qtd_prioridade_baixa
  FROM ${catalogo}.${schema_gold}.prioridade_inspecao_uc
  GROUP BY id_conjunto
),
-- 5. Total de UCs por conjunto (para contexto)
total_ucs_conjunto AS (
  SELECT
    id_conjunto,
    COUNT(*) AS total_ucs_conjunto
  FROM ${catalogo}.${schema_silver}.unidades_consumidoras
  GROUP BY id_conjunto
),
-- Cartesiano de conjuntos × dias (últimos 90 dias)
base_conjunto_dia AS (
  SELECT DISTINCT
    c.id_conjunto,
    d.dia
  FROM (SELECT DISTINCT id_conjunto FROM ${catalogo}.${schema_silver}.unidades_consumidoras) c
  CROSS JOIN (
    SELECT DISTINCT data AS dia
    FROM ${catalogo}.${schema_silver}.consumo_diario
    WHERE data >= DATE_SUB(CURRENT_DATE(), 90)
  ) d
),
-- FULL OUTER JOIN das 5 origens
integracao AS (
  SELECT
    COALESCE(b.id_conjunto, i.id_conjunto, ch.id_conjunto, co.id_conjunto) AS id_conjunto,
    COALESCE(b.dia, i.dia, ch.dia, co.dia) AS dia,
    
    -- Dados de interrupções
    COALESCE(i.qtd_interrupcoes_dia, 0) AS qtd_interrupcoes_dia,
    COALESCE(i.total_ucs_afetadas, 0) AS total_ucs_afetadas,
    COALESCE(i.total_horas_interrupcao, 0) AS total_horas_interrupcao,
    i.maior_interrupcao_horas,
    COALESCE(i.qtd_interrupcoes_climaticas, 0) AS qtd_interrupcoes_climaticas,
    
    -- Dados de chamados
    COALESCE(ch.qtd_chamados_dia, 0) AS qtd_chamados_dia,
    COALESCE(ch.qtd_chamados_negativos, 0) AS qtd_chamados_negativos,
    COALESCE(ch.qtd_mencoes_ouvidoria, 0) AS qtd_mencoes_ouvidoria,
    COALESCE(ch.qtd_relatos_risco_saude, 0) AS qtd_relatos_risco_saude,
    COALESCE(ch.qtd_chamados_urgencia_alta, 0) AS qtd_chamados_urgencia_alta,
    ch.motivo_predominante_dia,
    
    -- Dados de consumo
    co.qtd_ucs_com_leitura,
    co.consumo_medio_dia_kwh,
    co.consumo_total_dia_kwh,
    co.desvio_padrao_consumo,
    
    -- Dados de inspeção (não varia por dia, mas é contexto importante)
    COALESCE(ins.qtd_ucs_inspecao_pendente, 0) AS qtd_ucs_inspecao_pendente,
    COALESCE(ins.qtd_prioridade_alta, 0) AS qtd_inspecao_alta,
    COALESCE(ins.qtd_prioridade_media, 0) AS qtd_inspecao_media,
    COALESCE(ins.qtd_prioridade_baixa, 0) AS qtd_inspecao_baixa,
    
    -- Contexto do conjunto
    tc.total_ucs_conjunto
    
  FROM base_conjunto_dia b
  FULL OUTER JOIN interrupcoes_dia i
    ON b.id_conjunto = i.id_conjunto AND b.dia = i.dia
  FULL OUTER JOIN chamados_dia ch
    ON COALESCE(b.id_conjunto, i.id_conjunto) = ch.id_conjunto 
    AND COALESCE(b.dia, i.dia) = ch.dia
  FULL OUTER JOIN consumo_dia co
    ON COALESCE(b.id_conjunto, i.id_conjunto, ch.id_conjunto) = co.id_conjunto
    AND COALESCE(b.dia, i.dia, ch.dia) = co.dia
  LEFT JOIN inspecoes_pendentes ins
    ON COALESCE(b.id_conjunto, i.id_conjunto, ch.id_conjunto, co.id_conjunto) = ins.id_conjunto
  LEFT JOIN total_ucs_conjunto tc
    ON COALESCE(b.id_conjunto, i.id_conjunto, ch.id_conjunto, co.id_conjunto) = tc.id_conjunto
)
SELECT
  id_conjunto,
  CAST(id_conjunto AS STRING) AS nome_conjunto,
  dia,
  
  -- Métricas de interrupções
  qtd_interrupcoes_dia,
  total_ucs_afetadas,
  total_horas_interrupcao,
  maior_interrupcao_horas,
  qtd_interrupcoes_climaticas,
  
  -- Métricas de chamados
  qtd_chamados_dia,
  qtd_chamados_negativos,
  qtd_mencoes_ouvidoria,
  qtd_relatos_risco_saude,
  qtd_chamados_urgencia_alta,
  motivo_predominante_dia,
  
  -- Métricas de consumo
  qtd_ucs_com_leitura,
  consumo_medio_dia_kwh,
  consumo_total_dia_kwh,
  desvio_padrao_consumo,
  
  -- Métricas de inspeção
  qtd_ucs_inspecao_pendente,
  qtd_inspecao_alta,
  qtd_inspecao_media,
  qtd_inspecao_baixa,
  
  -- Contexto
  total_ucs_conjunto,
  
  -- AÇÃO RECOMENDADA (ordem de prioridade operacional)
  CASE
    -- 1. CRÍTICO: Relatos de risco à saúde (pessoas dependem de energia para vida)
    WHEN qtd_relatos_risco_saude > 0 THEN
      'CRÍTICO: ' || CAST(qtd_relatos_risco_saude AS STRING) || 
      ' relato(s) de risco à saúde. Priorizar atendimento imediato (oxigênio, diálise, equipamentos médicos).'
    
    -- 2. URGENTE: Ameaça de escalação para órgãos reguladores
    WHEN qtd_mencoes_ouvidoria > 0 THEN
      'URGENTE: ' || CAST(qtd_mencoes_ouvidoria AS STRING) || 
      ' cliente(s) mencionaram ouvidoria/ANEEL/Procon. Contatar para resolução antes de escalação formal.'
    
    -- 3. ALTO IMPACTO: Interrupção afetou muitas UCs ou durou muito
    WHEN total_ucs_afetadas >= (total_ucs_conjunto * 0.1) OR maior_interrupcao_horas >= 2.0 THEN
      'ALTO IMPACTO: Interrupção afetou ' || CAST(total_ucs_afetadas AS STRING) || 
      ' UCs (' || CAST(ROUND(100.0 * total_ucs_afetadas / NULLIF(total_ucs_conjunto, 0), 1) AS STRING) || 
      '% do conjunto). Verificar compensações regulatórias.'
    
    -- 4. INSPEÇÃO: Muitas UCs com prioridade alta de inspeção
    WHEN qtd_inspecao_alta >= 5 THEN
      'INSPEÇÃO: ' || CAST(qtd_inspecao_alta AS STRING) || 
      ' UCs com prioridade alta de inspeção. Planejar rota para visitas técnicas.'
    
    -- 5. ATENÇÃO: Muitos chamados negativos (insatisfação crescente)
    WHEN qtd_chamados_negativos >= 3 THEN
      'ATENÇÃO: ' || CAST(qtd_chamados_negativos AS STRING) || 
      ' chamados com sentimento negativo. Monitorar para prevenir escalação.'
    
    -- 6. MONITORAR: Interrupções climáticas (menor controle operacional)
    WHEN qtd_interrupcoes_climaticas > 0 AND qtd_interrupcoes_climaticas = qtd_interrupcoes_dia THEN
      'MONITORAR: Todas as ' || CAST(qtd_interrupcoes_dia AS STRING) || 
      ' interrupção(ões) foram por causas climáticas. Acompanhar previsão do tempo.'
    
    -- 7. ROTINA: Dia com interrupções ou chamados em volume normal
    WHEN qtd_interrupcoes_dia > 0 OR qtd_chamados_dia > 0 THEN
      'ROTINA: ' || 
      CASE WHEN qtd_interrupcoes_dia > 0 THEN CAST(qtd_interrupcoes_dia AS STRING) || ' interrupção(ões)' ELSE '' END ||
      CASE WHEN qtd_interrupcoes_dia > 0 AND qtd_chamados_dia > 0 THEN ' e ' ELSE '' END ||
      CASE WHEN qtd_chamados_dia > 0 THEN CAST(qtd_chamados_dia AS STRING) || ' chamado(s)' ELSE '' END ||
      '. Volume dentro do esperado.'
    
    -- 8. Normal: Dia sem eventos
    ELSE 'NORMAL: Sem interrupções ou chamados registrados.'
    
  END AS acao_recomendada
  
FROM integracao
WHERE 
  -- Filtra apenas dias com algum evento ou últimos 30 dias (para visão recente)
  qtd_interrupcoes_dia > 0 
  OR qtd_chamados_dia > 0 
  OR qtd_ucs_inspecao_pendente > 0
  OR dia >= DATE_SUB(CURRENT_DATE(), 30)
ORDER BY 
  dia DESC,
  id_conjunto;

-- Comentários nas colunas para o agente conversacional (RN-14)























