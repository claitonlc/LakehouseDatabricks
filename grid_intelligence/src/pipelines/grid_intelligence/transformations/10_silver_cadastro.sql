-- Silver: Cadastro de Unidades Consumidoras
--
-- Limpeza do cadastro:
-- - Normalização de classe_consumo (trim + lowercase)
-- - Bairro vazio vira 'nao informado' (não inventa dado)
-- - Descarta UC sem chave ou sem conjunto

CREATE OR REFRESH STREAMING TABLE ${catalogo}.${schema_silver}.unidades_consumidoras
TBLPROPERTIES ('delta.feature.timestampNtz' = 'supported')
AS SELECT
  id_uc,
  id_conjunto,
  lower(trim(classe_consumo)) AS classe_consumo,
  CASE 
    WHEN trim(bairro) = '' OR bairro IS NULL THEN 'nao informado'
    ELSE bairro
  END AS bairro,
  latitude,
  longitude
FROM STREAM(${catalogo}.${schema_bronze}.unidades_consumidoras)
WHERE id_uc IS NOT NULL 
  AND id_conjunto IS NOT NULL;
