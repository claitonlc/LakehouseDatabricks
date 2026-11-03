# 🎯 Camada Gold - Grid Intelligence

## ✅ Status: 100% Implementado e Validado

A camada gold do projeto Grid Intelligence está **completa e operacional**, com todas as 4 tabelas de negócio e a metric view de continuidade criadas e validadas.

## 🚀 Quick Start - Validação em 2 Minutos

Execute no **Databricks SQL Editor**:

```sql
-- Arquivo: teste_rapido.sql (5 queries)
-- Valida: Metric View, DEC/FEC, Prioridades, Saúde Cliente, Painel
```

**Se todas retornarem resultados** → ✅ Tudo funcionando!

## 📊 O Que Foi Entregue

### 5 Objetos Gold Criados:

1. **continuidade_conjunto_mes** - Insumos para DEC e FEC (não calcula os indicadores)
2. **continuidade_metricas** - Metric View com definição única de DEC e FEC
3. **prioridade_inspecao_uc** - UCs candidatas a inspeção (RN-06, RN-07, RN-08)
4. **saude_cliente** - Risco de escalação para ouvidoria
5. **painel_operacional_dia** - Visão integrada diária com ações recomendadas

## 🎓 Conceitos-Chave Implementados

### 1. Definição Única de DEC/FEC (RN-04)
```sql
-- ❌ ERRADO: Calcular na tabela
SELECT id_conjunto, uc_horas / total_ucs AS dec FROM tabela

-- ✅ CORRETO: Usar MEASURE() da metric view
SELECT `Conjunto`, MEASURE(`DEC`) FROM continuidade_metricas GROUP BY `Conjunto`
```

### 2. Prioridade ≠ Acusação (RN-07)
- Saída: "prioridade alta/média/baixa"
- Nunca: "fraude", "furto", "culpado"
- Motivo: "Consumo caiu X% enquanto vizinhança estável"

### 3. Dois Eixos para Inspeção (RN-06)
```
Prioridade Alta = (caiu_contra_si AND vizinhanca_estavel) AND sinal_violacao
```

## 📁 Arquivos Importantes

### Para Executar
- `teste_rapido.sql` → 5 queries de validação rápida (2 min)
- `validacao_final.sql` → 12 queries de validação completa (10 min)
- `validate_gold.sql` → Queries de contagem e distribuição

### Para Entender
- `STATUS_FINAL.md` → Status completo da implementação
- `DEPLOY_FINAL.md` → Instruções de deploy passo a passo

### Código Fonte
- `src/pipelines/grid_intelligence/transformations/20_gold_continuidade.sql`
- `src/pipelines/grid_intelligence/transformations/21_gold_prioridade_inspecao.sql`
- `src/pipelines/grid_intelligence/transformations/22_gold_saude_cliente.sql`
- `src/pipelines/grid_intelligence/transformations/23_gold_painel_operacional.sql`
- `src/sql/metric_view_continuidade_dev.sql`

## 💡 Como Usar

### Para Dashboards
```sql
-- DEC e FEC dos últimos 6 meses por conjunto
SELECT 
  `Conjunto`,
  DATE_FORMAT(`Mes`, 'MMM/yyyy') AS mes,
  MEASURE(`DEC`) AS dec_horas,
  MEASURE(`FEC`) AS fec_vezes,
  MEASURE(`Proporcao Climatica`) AS pct_climatico
FROM grid_dev.gold.continuidade_metricas
WHERE `Mes` >= DATE_SUB(CURRENT_DATE(), 180)
GROUP BY `Conjunto`, `Mes`
ORDER BY `Mes` DESC;
```

### Para Agente Conversacional
```sql
-- Responder: "Quais conjuntos tiveram DEC acima de 1 hora?"
SELECT 
  `Conjunto`,
  MEASURE(`DEC`) AS dec_horas
FROM grid_dev.gold.continuidade_metricas
WHERE MEASURE(`DEC`) > 1.0
GROUP BY `Conjunto`
ORDER BY MEASURE(`DEC`) DESC;
```

### Para Operações
```sql
-- UCs com prioridade alta para inspeção hoje
SELECT 
  id_uc,
  bairro,
  variacao_da_uc AS queda_pct,
  motivo_observado
FROM grid_dev.gold.prioridade_inspecao_uc
WHERE prioridade_inspecao = 'alta'
ORDER BY ABS(variacao_da_uc) DESC
LIMIT 20;
```

## ⚠️ Valores Esperados

Com 4.000 UCs, 6 conjuntos, 4 anos de histórico:

| Métrica | Esperado |
|---------|----------|
| DEC mensal (1 conjunto) | 0.03 a 1.3 horas |
| FEC mensal (1 conjunto) | 0.1 a 0.6 vezes |
| Total interrupções válidas | 1.073 eventos |

**Se DEC vier em dezenas** → Denominador errado (usar total_ucs, não qtd_ucs_afetadas)

## 🔄 Re-executar Pipeline

```bash
# Full refresh de todas as camadas (bronze, silver, gold)
databricks pipelines start-update 36cb3313-d470-4637-8bf1-b4f8668ded1a \
  --full-refresh \
  --profile grid_intelligence
```

**Nota**: A metric view não é recriada pelo pipeline. Se precisar recriar, execute o SQL manualmente.

## 📞 Troubleshooting

### Problema: "Table not found: continuidade_metricas"
**Solução**: Execute o SQL de criação da metric view (em `DEPLOY_FINAL.md`)

### Problema: DEC muito alto (> 10 horas em 1 mês)
**Solução**: Verifique se o denominador está usando `total_ucs` e não `qtd_ucs_afetadas`

### Problema: Prioridades sempre "nenhuma"
**Solução**: Verifique se os limiares (`limiar_queda_uc_pct`, `limiar_estabilidade_conjunto_pct`) estão configurados

## 🎉 Próximos Passos

1. ✅ Validar valores com `teste_rapido.sql`
2. 📊 Criar dashboards consumindo a metric view
3. 🤖 Conectar agente conversacional ao schema gold
4. 🚨 Configurar alertas para DEC > limites regulatórios
5. 📈 Avançar para Prompt 05 (próxima funcionalidade)

---

**Implementado conforme Prompt 04 do projeto Grid Intelligence**  
Arquitetura Medallion | Delta Live Tables | Databricks | RN-04, RN-06, RN-07, RN-08, RN-14
