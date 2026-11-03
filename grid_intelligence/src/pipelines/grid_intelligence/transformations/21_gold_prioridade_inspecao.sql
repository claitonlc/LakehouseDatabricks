-- Gold: Prioridade de Inspeção — RN-06, RN-07 e RN-08
--
-- DECISÃO DE ARQUITETURA:
-- A saída é PRIORIDADE (alta/média/baixa), NUNCA rótulo de fraude, furto ou culpado (RN-07).
-- Queda de consumo também é: mudança de morador, imóvel desocupado, defeito no medidor,
-- erro de leitura. O inspetor confirma no local. Este sistema apenas PRIORIZA a visita.
--
-- RN-06 — DOIS EIXOS SIMULTÂNEOS:
-- - Eixo 1: UC caiu contra seu próprio baseline (queda > limiar_queda_uc)
-- - Eixo 2: ENQUANTO vizinhança (conjunto) ficou estável (|variação| < limiar_estabilidade_conjunto)
-- Só o eixo 1 apontaria bairro inteiro após apagão. Os dois juntos isolam comportamento individual.
--
-- RN-08 — REGRA EXPLICÁVEL, NÃO MODELO:
-- Sem rótulo confiável de irregularidade, classificador supervisionado é teatro.
-- Toda pessoa deve conseguir reconstruir por que uma UC entrou na lista.
--
-- GRÃO: uma linha por UC candidata a inspeção
-- ORIGEM: silver.baseline_consumo (que já tem as duas janelas comparáveis prontas)

-- ====================================================================================
-- Prioridade de Inspeção por UC
-- ====================================================================================
CREATE OR REFRESH MATERIALIZED VIEW ${catalogo}.${schema_gold}.prioridade_inspecao_uc
COMMENT 'Lista priorizada de unidades consumidoras candidatas a inspeção técnica. A prioridade é calculada com base em dois eixos: queda no consumo da UC contra seu próprio baseline enquanto a vizinhança permanece estável. IMPORTANTE: Esta é uma lista de prioridades, não acusações. Queda de consumo pode indicar mudança de morador, imóvel vazio, defeito de medidor ou erro de leitura.'
AS
WITH enriquecimento AS (
  SELECT
    b.id_uc,
    b.id_conjunto,
    CAST(b.id_conjunto AS STRING) AS nome_conjunto,
    uc.bairro,
    uc.classe_consumo,
    b.media_baseline AS consumo_medio_baseline_kwh,
    b.media_recente AS consumo_medio_recente_kwh,
    b.dias_baseline AS dias_no_baseline,
    b.dias_recente AS dias_no_periodo_recente,
    b.variacao_pct AS variacao_da_uc,
    b.variacao_conjunto_pct AS variacao_do_conjunto,
    
    -- Limiares vindos da configuração do pipeline (valores padrão se não especificados)
    COALESCE(CAST('${limiar_queda_uc_pct}' AS DOUBLE), -20.0) AS limiar_queda,
    COALESCE(CAST('${limiar_estabilidade_conjunto_pct}' AS DOUBLE), 5.0) AS limiar_estabilidade,
    
    -- Sinal de violação no medidor (dados físicos de campo)
    -- TODO: integrar com sistema de telemetria de medidores quando disponível
    FALSE AS sinal_violacao_recente
    
  FROM ${catalogo}.${schema_silver}.baseline_consumo b
  INNER JOIN ${catalogo}.${schema_silver}.unidades_consumidoras uc
    ON b.id_uc = uc.id_uc
  WHERE 
    -- Só considera UCs com evidência suficiente nas duas janelas
    b.dias_baseline >= 60
    AND b.dias_recente >= 20
    AND b.media_baseline IS NOT NULL
    AND b.media_recente IS NOT NULL
    AND b.media_baseline > 0
),
classificacao AS (
  SELECT
    *,
    -- EIXO 1: UC caiu contra si mesma (variação negativa maior que o limiar)
    variacao_da_uc < limiar_queda AS caiu_contra_si,
    
    -- EIXO 2: Vizinhança (conjunto) permaneceu estável (variação dentro da faixa)
    ABS(variacao_do_conjunto) < limiar_estabilidade AS vizinhanca_estavel,
    
    -- Os dois eixos juntos (RN-06)
    (variacao_da_uc < limiar_queda) 
      AND (ABS(variacao_do_conjunto) < limiar_estabilidade) AS atende_os_dois_eixos
    
  FROM enriquecimento
),
resultado_completo AS (
SELECT
  id_uc,
  id_conjunto,
  nome_conjunto,
  bairro,
  classe_consumo,
  
  -- PRIORIDADE (nunca "fraude", "furto" ou "culpado")
  CASE
    -- Alta: dois eixos + sinal físico de violação
    WHEN atende_os_dois_eixos AND sinal_violacao_recente THEN 'alta'
    -- Média: dois eixos sem sinal, OU sinal sem queda relevante
    WHEN atende_os_dois_eixos OR sinal_violacao_recente THEN 'media'
    -- Baixa: caiu junto com a vizinhança (evento de rede, não individual)
    WHEN caiu_contra_si AND NOT vizinhanca_estavel THEN 'baixa'
    -- Nenhuma anomalia detectada
    ELSE 'nenhuma'
  END AS prioridade_inspecao,
  
  -- Flags dos dois eixos (explícitos para auditoria)
  caiu_contra_si,
  vizinhanca_estavel,
  atende_os_dois_eixos,
  sinal_violacao_recente,
  
  -- Os números que sustentam as flags
  variacao_da_uc,
  variacao_do_conjunto,
  consumo_medio_baseline_kwh,
  consumo_medio_recente_kwh,
  dias_no_baseline,
  dias_no_periodo_recente,
  
  -- MOTIVO OBSERVADO: linguagem de negócio, não acusação (RN-07)
  CASE
    WHEN atende_os_dois_eixos AND sinal_violacao_recente THEN
      'Consumo caiu ' || CAST(ROUND(ABS(variacao_da_uc), 1) AS STRING) || 
      '% enquanto vizinhança manteve-se estável. Medidor apresenta sinal de violação física.'
    WHEN atende_os_dois_eixos THEN
      'Consumo caiu ' || CAST(ROUND(ABS(variacao_da_uc), 1) AS STRING) || 
      '% enquanto vizinhança (variação de ' || CAST(ROUND(variacao_do_conjunto, 1) AS STRING) || 
      '%) manteve-se estável. Recomenda-se verificar: mudança de morador, imóvel desocupado ou defeito no medidor.'
    WHEN sinal_violacao_recente THEN
      'Medidor apresenta sinal de violação física. Consumo variou ' || 
      CAST(ROUND(variacao_da_uc, 1) AS STRING) || '% no período.'
    WHEN caiu_contra_si AND NOT vizinhanca_estavel THEN
      'Consumo caiu ' || CAST(ROUND(ABS(variacao_da_uc), 1) AS STRING) || 
      '% acompanhando queda de ' || CAST(ROUND(variacao_do_conjunto, 1) AS STRING) || 
      '% da vizinhança. Provável evento de rede, não caso individual.'
    ELSE
      'Consumo dentro do padrão esperado (variação de ' || 
      CAST(ROUND(variacao_da_uc, 1) AS STRING) || '%).'
  END AS motivo_observado
  
FROM classificacao
),
filtrado AS (
  SELECT *
  FROM resultado_completo
  WHERE 
    -- Só exibe UCs com alguma prioridade de inspeção (economiza storage e foco do inspetor)
    prioridade_inspecao IN ('alta', 'media', 'baixa')
)
SELECT *
FROM filtrado
ORDER BY
  CASE prioridade_inspecao 
    WHEN 'alta' THEN 1
    WHEN 'media' THEN 2
    WHEN 'baixa' THEN 3
  END,
  ABS(variacao_da_uc) DESC;

-- Comentários nas colunas para o agente conversacional (RN-14)
















