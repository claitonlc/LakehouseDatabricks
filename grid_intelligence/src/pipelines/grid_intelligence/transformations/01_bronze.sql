-- Camada Bronze — Ingestão Fiel
-- 
-- RN-11: A ingestão não filtra, não corrige e não aplica regra de negócio.
--        Consumo negativo, interrupção < 3 minutos, cadastro incompleto — tudo entra como chegou.
--        Filtrar aqui seria destruição de evidência. Quem descarta é a silver, com regra visível.
--
-- RN-12: Todo registro ingerido carrega origem (arquivo_origem) e momento de ingestão (ingerido_bronze_em).
--
-- ARMADILHA: Cada base é um único arquivo sobrescrito quando regerado.
--            Auto Loader com allowOverwrites => true reprocessa, mas streaming table é append-only.
--            Resultado: linhas antigas permanecem e o volume dobra.
--            Solução: Rodar o pipeline com full refresh após regerar os dados.

-- ====================================================================================
-- unidades_consumidoras (4.000 linhas esperadas)
-- ====================================================================================
CREATE OR REFRESH STREAMING TABLE ${catalogo}.${schema_bronze}.unidades_consumidoras
TBLPROPERTIES ('delta.feature.timestampNtz' = 'supported')
AS SELECT
  *,
  _metadata.file_path AS arquivo_origem,
  current_timestamp() AS ingerido_bronze_em
FROM STREAM read_files(
  '${volume_landing}/unidades_consumidoras/',
  format => 'parquet'
);

-- ====================================================================================
-- interrupcoes (1.383 linhas esperadas, ~22% abaixo de 3 minutos)
-- ====================================================================================
CREATE OR REFRESH STREAMING TABLE ${catalogo}.${schema_bronze}.interrupcoes
TBLPROPERTIES ('delta.feature.timestampNtz' = 'supported')
AS SELECT
  *,
  _metadata.file_path AS arquivo_origem,
  current_timestamp() AS ingerido_bronze_em
FROM STREAM read_files(
  '${volume_landing}/interrupcoes/',
  format => 'parquet'
);

-- ====================================================================================
-- consumo_diario (~5,85 milhões de linhas esperadas)
-- ====================================================================================
CREATE OR REFRESH STREAMING TABLE ${catalogo}.${schema_bronze}.consumo_diario
TBLPROPERTIES ('delta.feature.timestampNtz' = 'supported')
AS SELECT
  *,
  _metadata.file_path AS arquivo_origem,
  current_timestamp() AS ingerido_bronze_em
FROM STREAM read_files(
  '${volume_landing}/consumo_diario/',
  format => 'parquet'
);

-- ====================================================================================
-- chamados (2.801 linhas esperadas)
-- ====================================================================================
CREATE OR REFRESH STREAMING TABLE ${catalogo}.${schema_bronze}.chamados
TBLPROPERTIES ('delta.feature.timestampNtz' = 'supported')
AS SELECT
  *,
  _metadata.file_path AS arquivo_origem,
  current_timestamp() AS ingerido_bronze_em
FROM STREAM read_files(
  '${volume_landing}/chamados/',
  format => 'parquet'
);
