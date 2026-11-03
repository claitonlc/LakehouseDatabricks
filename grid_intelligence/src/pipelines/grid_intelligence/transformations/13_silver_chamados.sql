-- Silver: Chamados - Anonimização e Enriquecimento por Regex (Rota Determinística)
--
-- LIMITAÇÕES DA EXTRAÇÃO POR REGRA (não por IA):
-- - Ironia e negação: "Que ótimo, mais um dia sem luz" → positive (errado)
-- - Sinônimo fora da lista: "tá tudo apagado" pega; "fiquei no breu" não
-- - Motivo composto: falta energia + conta alta recebe um rótulo só
-- - Nome com apelido: se cliente se apresenta diferente da coluna, regex não casa
--
-- VANTAGENS: determinística, rápida (segundos), sem custo, reprodutível
--
-- RN-09: Anonimização acontece ANTES do enriquecimento
-- RN-10: Column mask protege leitura da bronze (aplicado separadamente)

-- ====================================================================================
-- 1. chamados_anonimizados: Remove nome, CPF e telefone (RN-09)
-- ====================================================================================
CREATE OR REFRESH MATERIALIZED VIEW ${catalogo}.${schema_silver}.chamados_anonimizados
AS
SELECT
  c.id_chamado,
  c.id_uc,
  CAST(c.abertura AS TIMESTAMP) AS data_hora,
  to_date(c.abertura) AS data_chamado,
  hour(c.abertura) AS hora_chamado,
  -- Anonimização em 3 etapas: nome (coluna), CPF (regex), telefone (regex)
  regexp_replace(
    regexp_replace(
      replace(c.transcricao, c.nome_solicitante, '[MASCARADO]'),
      '[0-9]{3}\\.[0-9]{3}\\.[0-9]{3}-[0-9]{2}',                    -- CPF formatado
      '[MASCARADO]'),
    '\\([0-9]{2}\\)\\s*9?[0-9]{4}-?[0-9]{4}',                       -- telefone com DDD
    '[MASCARADO]') AS transcricao_anonimizada,
  -- Join com cadastro para análise não refazer
  uc.id_conjunto,
  uc.bairro,
  uc.classe_consumo,
  'regras_de_texto' AS anonimizado_por
FROM ${catalogo}.${schema_bronze}.chamados c
INNER JOIN ${catalogo}.${schema_silver}.unidades_consumidoras uc
  ON c.id_uc = uc.id_uc;

-- ====================================================================================
-- 2. chamados_enriquecidos: Extrai sentimento, motivo, urgência do texto JÁ ANONIMIZADO
-- ====================================================================================
CREATE OR REFRESH MATERIALIZED VIEW ${catalogo}.${schema_silver}.chamados_enriquecidos
AS
SELECT
  id_chamado,
  id_uc,
  data_hora,
  data_chamado,
  hora_chamado,
  transcricao_anonimizada,
  id_conjunto,
  bairro,
  classe_consumo,
  anonimizado_por,
  
  -- Sentimento: termos de insatisfação vs agradecimento
  CASE
    WHEN transcricao_anonimizada RLIKE '(?i)pessimo|horrivel|inaceitavel|revoltante|absurdo|indignado|furioso|vergonha'
      THEN 'negative'
    WHEN transcricao_anonimizada RLIKE '(?i)obrigado|obrigada|agradeco|excelente|parabens|otimo'
      THEN 'positive'
    ELSE 'neutral'
  END AS sentimento,
  
  -- Motivo: ordem importa! Mais específico antes de genérico
  CASE
    WHEN transcricao_anonimizada RLIKE '(?i)dialise|oxigenio|remedio na geladeira|crianca pequena|idoso acamado'
      THEN 'religacao_urgente'
    WHEN transcricao_anonimizada RLIKE '(?i)escuro|sem energia|apagou|falta de energia|sem luz|ficou sem'
      THEN 'falta_energia'
    WHEN transcricao_anonimizada RLIKE '(?i)piscando|oscila|queimou|tensao|variacao'
      THEN 'oscilacao_tensao'
    WHEN transcricao_anonimizada RLIKE '(?i)releitura|estimativa|nao bate|medicao errada'
      THEN 'erro_leitura'
    WHEN transcricao_anonimizada RLIKE '(?i)conta veio|dobro|fatura subiu|trezentos reais|muito cara'
      THEN 'fatura_alta'
    WHEN transcricao_anonimizada RLIKE '(?i)poste|galho|lampada da rua|iluminacao publica'
      THEN 'poste_avariado'
    WHEN transcricao_anonimizada RLIKE '(?i)religacao|religar|paguei|quitar|debito'
      THEN 'religacao'
    ELSE 'duvida_cadastral'
  END AS motivo,
  
  -- Equipamento citado: alternação dos conhecidos
  regexp_extract(
    transcricao_anonimizada,
    '(?i)(poste|transformador|medidor|religador|disjuntor|cabo|chave|lampada)',
    1
  ) AS equipamento_citado,
  
  -- Risco à saúde: termos críticos
  transcricao_anonimizada RLIKE '(?i)oxigenio|dialise|remedio|crianca|hospital|faisca|incendio|idoso|acamado' 
    AS risco_a_saude,
  
  -- Urgência: alta se risco, média para falta/poste/oscilação, baixa no resto
  CASE
    WHEN transcricao_anonimizada RLIKE '(?i)oxigenio|dialise|remedio|crianca|hospital|faisca|incendio|idoso|acamado'
      THEN 'alta'
    WHEN transcricao_anonimizada RLIKE '(?i)sem energia|falta|poste|oscila|piscando'
      THEN 'media'
    ELSE 'baixa'
  END AS urgencia,
  
  -- Ameaçou ouvidoria/ANEEL/Procon
  transcricao_anonimizada RLIKE '(?i)ouvidoria|aneel|procon|processo|advogado|justica' 
    AS ameacou_ouvidoria,
  
  'regras_de_texto' AS enriquecido_por
FROM ${catalogo}.${schema_silver}.chamados_anonimizados;
