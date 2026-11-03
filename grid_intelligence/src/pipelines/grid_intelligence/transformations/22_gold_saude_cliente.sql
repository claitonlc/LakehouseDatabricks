-- Gold: Saúde do Cliente — Risco de Ouvidoria
--
-- DECISÃO DE MODELAGEM:
-- O grão é CLIENTE, não UC. Quem abre reclamação na ouvidoria é a pessoa física/jurídica,
-- e ela pode ter múltiplas UCs. Agrupar por UC esconderia o cliente que ligou uma vez
-- por cada instalação — é a coluna qtd_ucs_com_chamado que torna isso visível.
--
-- OBSERVAÇÃO SOBRE O DATASET:
-- A base de chamados não possui coluna id_cliente explícita. Como proxy, usamos id_uc
-- como identificador do cliente (assumindo 1 UC = 1 cliente no dataset sintético).
-- Em um sistema real, seria feito JOIN com tabela de relacionamento UC-Cliente.
--
-- CLASSIFICAÇÃO DE RISCO (ordem de peso):
-- 1. Menção explícita a ouvidoria/ANEEL/Procon → risco ALTO
-- 2. Reincidência (3+ chamados em 30 dias) com tom negativo → risco ALTO
-- 3. Relato de risco à saúde → risco MÉDIO (pode escalar se não resolvido)
-- 4. Chamados frequentes sem menção a órgãos reguladores → risco MÉDIO
-- 5. Poucos chamados, tom neutro/positivo → risco BAIXO
--
-- GRÃO: um registro por cliente (id_uc usado como proxy de cliente)
-- ORIGEM: silver.chamados_enriquecidos

-- ====================================================================================
-- Saúde do Cliente — Risco de Escalação para Ouvidoria
-- ====================================================================================
CREATE OR REFRESH MATERIALIZED VIEW ${catalogo}.${schema_gold}.saude_cliente
COMMENT 'Análise de risco de escalação para ouvidoria por cliente. Classifica clientes por probabilidade de abrir reclamação formal em órgãos reguladores (ANEEL, Procon) baseado em: menções explícitas a esses órgãos, reincidência de chamados com tom negativo, relatos de risco à saúde. O objetivo é permitir ação proativa antes da escalação formal.'
AS
WITH janela_analise AS (
  -- Define janela de 30 dias para análise de reincidência
  SELECT
    MAX(data_chamado) AS data_maxima,
    DATE_SUB(MAX(data_chamado), 30) AS inicio_janela
  FROM ${catalogo}.${schema_silver}.chamados_enriquecidos
),
ultimos_registros AS (
  SELECT
    c.*,
    ROW_NUMBER() OVER (PARTITION BY c.id_uc ORDER BY c.data_hora DESC) AS rn
  FROM ${catalogo}.${schema_silver}.chamados_enriquecidos c
),
agregacao_por_cliente AS (
  SELECT
    -- Proxy de cliente (em sistema real: JOIN com tabela cliente-UC)
    c.id_uc AS id_cliente,
    
    -- Localização e contexto (pega do primeiro registro)
    FIRST(c.id_conjunto) AS id_conjunto,
    CAST(FIRST(c.id_conjunto) AS STRING) AS nome_conjunto,
    FIRST(c.bairro) AS bairro,
    
    -- Contagens gerais
    COUNT(*) AS qtd_chamados,
    COUNT(DISTINCT c.id_uc) AS qtd_ucs_com_chamado,
    
    -- Análise de sentimento
    SUM(CASE WHEN c.sentimento = 'negative' THEN 1 ELSE 0 END) AS qtd_chamados_negativos,
    AVG(CASE WHEN c.sentimento = 'negative' THEN 1.0 ELSE 0.0 END) AS proporcao_negativa,
    
    -- Sinais de escalação
    SUM(CASE WHEN c.ameacou_ouvidoria THEN 1 ELSE 0 END) AS qtd_mencoes_ouvidoria,
    SUM(CASE WHEN c.risco_a_saude THEN 1 ELSE 0 END) AS qtd_chamados_risco_saude,
    SUM(CASE WHEN c.urgencia = 'alta' THEN 1 ELSE 0 END) AS qtd_urgencia_alta,
    
    -- Reincidência (3+ chamados em 30 dias)
    SUM(CASE 
      WHEN c.data_chamado >= (SELECT inicio_janela FROM janela_analise) 
      THEN 1 ELSE 0 
    END) >= 3 AS reincidente,
    
    -- Motivo predominante (mode para estabilidade do resultado)
    MODE(c.motivo) AS motivo_predominante,
    
    -- Último equipamento e fala (do registro mais recente)
    MAX(CASE WHEN rn = 1 THEN c.equipamento_citado END) AS ultimo_equipamento_citado,
    MAX(CASE WHEN rn = 1 THEN c.transcricao_anonimizada END) AS ultima_fala,
    
    -- Janela temporal dos chamados
    MIN(c.data_chamado) AS primeiro_chamado_em,
    MAX(c.data_chamado) AS ultimo_chamado_em
    
  FROM ultimos_registros c
  GROUP BY c.id_uc
),
classificacao AS (
  SELECT
    *,
    -- CLASSIFICAÇÃO DE RISCO DE OUVIDORIA (ordem de prioridade)
    CASE
      -- ALTO: mencionou órgãos reguladores explicitamente
      WHEN qtd_mencoes_ouvidoria > 0 THEN 'alto'
      -- ALTO: reincidente (3+ chamados em 30d) com tom predominantemente negativo
      WHEN reincidente AND proporcao_negativa >= 0.5 THEN 'alto'
      -- MÉDIO: risco à saúde (pode escalar rapidamente se não resolvido)
      WHEN qtd_chamados_risco_saude > 0 THEN 'medio'
      -- MÉDIO: chamados frequentes mesmo sem ameaça explícita
      WHEN qtd_chamados >= 5 THEN 'medio'
      -- BAIXO: poucos chamados, tom não negativo
      ELSE 'baixo'
    END AS risco_ouvidoria
  FROM agregacao_por_cliente
)
SELECT
  id_cliente,
  id_conjunto,
  nome_conjunto,
  bairro,
  qtd_chamados,
  qtd_ucs_com_chamado,
  qtd_chamados_negativos,
  ROUND(proporcao_negativa, 3) AS proporcao_negativa,
  qtd_mencoes_ouvidoria,
  qtd_chamados_risco_saude,
  qtd_urgencia_alta,
  reincidente,
  motivo_predominante,
  ultimo_equipamento_citado,
  -- Trunca última fala para primeiros 500 caracteres (contexto suficiente)
  SUBSTRING(ultima_fala, 1, 500) AS ultima_fala,
  primeiro_chamado_em,
  ultimo_chamado_em,
  risco_ouvidoria
FROM classificacao
ORDER BY
  CASE risco_ouvidoria
    WHEN 'alto' THEN 1
    WHEN 'medio' THEN 2
    WHEN 'baixo' THEN 3
  END,
  qtd_chamados DESC;

-- Comentários nas colunas para o agente conversacional (RN-14)

















