-- Metric View: Continuidade — Definição Única de DEC e FEC (Ambiente DEV)
--
-- DECISÃO DE ARQUITETURA (RN-04):
-- Esta é a ÚNICA definição de DEC e FEC no sistema. Dashboards, agentes e relatórios
-- consultam esta view com MEASURE() - nunca calculam DEC/FEC diretamente.

-- Posicionar contexto de catálogo e schema ANTES do bloco $$
USE CATALOG grid_dev;
USE SCHEMA gold;

CREATE OR REPLACE VIEW continuidade_metricas
WITH METRICS
LANGUAGE YAML
AS $$
# Metric View de Continuidade - DEC e FEC

# Tabela base
table:
  name: continuidade_conjunto_mes
  comment: Indicadores de continuidade do fornecimento de energia por conjunto e mês. DEC mede quantas horas em média cada UC ficou sem energia. FEC mede quantas vezes em média cada UC sofreu interrupção. Ambos são regulados pela ANEEL e geram compensação financeira quando ultrapassam limites

# Dimensões
dimensions:
  - name: Conjunto
    expr: nome_conjunto
    synonyms:
      - região
      - area
      - localidade
      - zona
    comment: Nome do conjunto elétrico para filtrar e agrupar resultados por área geográfica

  - name: Codigo do Conjunto
    expr: id_conjunto
    synonyms:
      - id conjunto
      - identificador conjunto
      - código conjunto
    comment: Identificador numérico do conjunto

  - name: Municipio
    expr: municipio
    synonyms:
      - cidade
      - município
      - localização
    comment: Município ou região do conjunto

  - name: Mes
    expr: mes_apuracao
    synonyms:
      - mês de apuração
      - período
      - referência
      - data
    comment: Mês de referência da apuração (sempre primeiro dia do mês)

# Medidas
measures:
  - name: DEC
    expr: SUM(uc_horas_interrompidas) / SUM(total_ucs)
    format: "#,##0.00"
    synonyms:
      - duração equivalente
      - horas sem luz
      - tempo sem energia
      - dec horas
    comment: Duração Equivalente de Interrupção por UC. Mede quantas horas em média cada unidade consumidora do conjunto ficou sem energia no período. Calculado como soma de horas-UC interrompidas dividido pelo total de UCs do conjunto

  - name: FEC
    expr: SUM(uc_interrupcoes) / SUM(total_ucs)
    format: "#,##0.00"
    synonyms:
      - frequência equivalente
      - quantidade de interrupções
      - número de faltas
      - vezes sem luz
    comment: Frequência Equivalente de Interrupção por UC. Mede quantas vezes em média cada unidade consumidora do conjunto sofreu interrupção no período. Calculado como soma de interrupções-UC dividido pelo total de UCs

  - name: DEC Acumulado
    expr: SUM(uc_horas_interrompidas) / (SUM(total_ucs) / COUNT(DISTINCT mes_apuracao))
    format: "#,##0.00"
    synonyms:
      - dec total
      - dec do período
      - acumulado de horas
    comment: DEC acumulado considerando múltiplos meses. Diferente do DEC mensal porque divide pela base média de UCs (não pela soma repetida mês a mês). Use esta medida para períodos maiores que um mês

  - name: Interrupcoes
    expr: SUM(qtd_interrupcoes)
    format: "#,##0"
    synonyms:
      - quantidade de eventos
      - eventos
      - ocorrências
      - faltas
    comment: Quantidade total de eventos de interrupção no período (apenas eventos com 3 minutos ou mais conforme regulação)

  - name: Interrupcoes Climaticas
    expr: SUM(qtd_interrupcoes_climaticas)
    format: "#,##0"
    synonyms:
      - eventos climáticos
      - interrupções por clima
      - causas naturais
    comment: Quantidade de interrupções causadas por fatores climáticos como tempestades, raios e ventos fortes

  - name: Proporcao Climatica
    expr: SUM(qtd_interrupcoes_climaticas) / NULLIF(SUM(qtd_interrupcoes), 0)
    format: "0.0%"
    synonyms:
      - percentual climático
      - proporção de clima
      - taxa climática
    comment: Proporção de interrupções causadas por fatores climáticos em relação ao total de interrupções. Útil para separar o que é intempérie do que é problema da rede

  - name: Interrupcoes Programadas
    expr: SUM(qtd_interrupcoes_programadas)
    format: "#,##0"
    synonyms:
      - manutenções planejadas
      - eventos programados
      - desligamentos programados
    comment: Quantidade de interrupções programadas com aviso prévio para manutenção ou obras. Têm tratamento regulatório diferente das interrupções não programadas

  - name: Horas UC Interrompidas
    expr: SUM(uc_horas_interrompidas)
    format: "#,##0.0"
    synonyms:
      - total horas uc
      - horas totais
      - soma horas
    comment: Total de horas-UC sem energia. É o numerador do DEC. Representa a soma de (duração × UCs afetadas) de todos os eventos

  - name: Maior Interrupcao
    expr: MAX(maior_duracao_horas)
    format: "#,##0.00"
    synonyms:
      - pior evento
      - interrupção mais longa
      - maior duração
    comment: Duração em horas da interrupção mais longa ocorrida no período

  - name: Total de UCs
    expr: SUM(total_ucs) / COUNT(DISTINCT mes_apuracao)
    format: "#,##0"
    synonyms:
      - base de clientes
      - quantidade de ucs
      - unidades consumidoras
    comment: Total de unidades consumidoras na base. Em agregações multi-mês usa a média para não multiplicar a base pelo número de meses
$$;
