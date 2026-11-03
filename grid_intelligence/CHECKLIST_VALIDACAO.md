# ✅ Checklist de Validação - Camada Gold

## 📋 Execute este checklist para confirmar que está tudo OK

### 1. Tabelas Gold Existem? 

Execute no SQL Editor:
```sql
SHOW TABLES IN grid_dev.gold;
```

**Esperado**: 5 tabelas
- [ ] `continuidade_conjunto_mes`
- [ ] `continuidade_metricas`  
- [ ] `painel_operacional_dia`
- [ ] `prioridade_inspecao_uc`
- [ ] `saude_cliente`

---

### 2. Metric View Funciona?

```sql
SELECT `Conjunto`, MEASURE(`DEC`), MEASURE(`FEC`)
FROM grid_dev.gold.continuidade_metricas
GROUP BY `Conjunto`
LIMIT 5;
```

**Esperado**: Retorna 5-6 linhas com valores numéricos
- [ ] Query executou sem erro
- [ ] DEC está entre 0.01 e 15 (ordem de grandeza correta)
- [ ] FEC está entre 0.1 e 20 (ordem de grandeza correta)

---

### 3. DEC e DEC Acumulado São Diferentes?

```sql
SELECT 
  `Conjunto`,
  ROUND(AVG(MEASURE(`DEC`)), 3) AS dec_medio_mensal,
  ROUND(MEASURE(`DEC Acumulado`), 3) AS dec_acumulado
FROM grid_dev.gold.continuidade_metricas
GROUP BY `Conjunto`;
```

**Esperado**: Valores diferentes
- [ ] dec_medio_mensal < dec_acumulado (acumulado deve ser maior)
- [ ] Valores fazem sentido (acumulado = soma de meses)

---

### 4. Prioridades de Inspeção?

```sql
SELECT prioridade_inspecao, COUNT(*) AS qtd
FROM grid_dev.gold.prioridade_inspecao_uc
GROUP BY prioridade_inspecao;
```

**Esperado**: 3 categorias
- [ ] Há UCs com prioridade 'alta'
- [ ] Há UCs com prioridade 'media'
- [ ] Há UCs com prioridade 'baixa'
- [ ] NENHUMA linha com palavra "fraude", "furto" ou "culpado"

---

### 5. Saúde do Cliente?

```sql
SELECT risco_ouvidoria, COUNT(*) AS qtd
FROM grid_dev.gold.saude_cliente
GROUP BY risco_ouvidoria;
```

**Esperado**: 3 níveis de risco
- [ ] Há clientes com risco 'alto'
- [ ] Há clientes com risco 'medio'
- [ ] Há clientes com risco 'baixo'

---

### 6. Painel Operacional?

```sql
SELECT COUNT(*) AS total_dias
FROM grid_dev.gold.painel_operacional_dia;
```

**Esperado**: > 0 registros
- [ ] Retornou pelo menos 100 registros
- [ ] Coluna `acao_recomendada` tem texto legível

---

### 7. Total de Interrupções Bate?

```sql
-- Deve ser 1.073 em todas as camadas
SELECT 'Silver' AS camada, COUNT(*) AS total 
FROM grid_dev.silver.interrupcoes_validas
UNION ALL
SELECT 'Gold Tabela', SUM(qtd_interrupcoes)
FROM grid_dev.gold.continuidade_conjunto_mes
UNION ALL
SELECT 'Gold Metric', SUM(MEASURE(`Interrupcoes`))
FROM grid_dev.gold.continuidade_metricas;
```

**Esperado**: Mesmo valor nas 3 linhas
- [ ] Silver = Gold Tabela = Gold Metric
- [ ] Valor aproximado: 1.073 eventos

---

### 8. Teste de Ação Recomendada

```sql
SELECT acao_recomendada, COUNT(*) AS qtd
FROM grid_dev.gold.painel_operacional_dia
GROUP BY SUBSTRING(acao_recomendada, 1, 20)
ORDER BY qtd DESC
LIMIT 10;
```

**Esperado**: Ações priorizadas
- [ ] Vê ações como "CRÍTICO:", "URGENTE:", "ALTO IMPACTO:", "NORMAL:"
- [ ] Distribuição faz sentido (mais NORMAL/ROTINA que CRÍTICO)

---

## 🎯 Resultado Final

### Quantas caixas você marcou? _____ / 20

- **20/20** = ✅ Perfeito! Tudo funcionando 100%
- **18-19** = ✅ Muito bom! Pequenos ajustes podem ser necessários
- **15-17** = ⚠️ Bom, mas verifique os itens não marcados
- **< 15** = ❌ Precisa revisão - execute `validacao_final.sql` para detalhes

---

## 📊 Validação Adicional Recomendada

Se todos os 20 itens estão OK, execute também:

1. **Validação Completa**: `validacao_final.sql` (12 queries)
2. **Teste de Performance**: Consultas com `GROUP BY` em múltiplas dimensões
3. **Teste de Agente**: Fazer perguntas em linguagem natural e ver se synonyms funcionam

---

## ✅ Aprovação Final

- [ ] Todos os 20 itens do checklist estão OK
- [ ] Valores de DEC/FEC estão na ordem de grandeza esperada
- [ ] Nenhum erro ao executar queries
- [ ] Documentação revisada (`STATUS_FINAL.md`)

**Assinatura**: ______________ **Data**: ______________

---

**🎉 Se tudo está OK, a camada gold está completa e pronta para produção!**
