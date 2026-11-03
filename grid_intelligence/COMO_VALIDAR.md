# 🎯 Como Validar a Camada Gold

## Erro Encontrado e Corrigido

❌ **Erro**: `DESCRIBE VIEW` e `SHOW VIEWS` não funcionam no Databricks SQL  
✅ **Solução**: Use `SHOW TABLES` e `DESCRIBE TABLE`

Arquivos corrigidos:
- ✅ `validacao_final.sql`
- ✅ `CHECKLIST_VALIDACAO.md`
- ✅ Criado `validacao_simples.sql` (novo, mais seguro)

## 📝 3 Formas de Validar (Escolha Uma)

### 1️⃣ VALIDAÇÃO RÁPIDA (2 minutos) ⭐ RECOMENDADO

**Arquivo**: `teste_rapido.sql`

Execute as 5 queries sequencialmente. Se todas retornarem resultados → ✅ OK!

```sql
-- 1. Metric view existe?
-- 2. DEC e FEC calculam?
-- 3. Prioridades funcionam?
-- 4. Saúde cliente classifica?
-- 5. Painel tem ações?
```

### 2️⃣ VALIDAÇÃO SIMPLES (5 minutos)

**Arquivo**: `validacao_simples.sql`

Execute **uma query por vez** (não todas juntas). 10 queries de validação focadas.

```sql
-- Query 1: Listar tabelas
-- Query 2: Testar metric view
-- Query 3: Ordem de grandeza
-- ... (execute uma de cada vez)
```

### 3️⃣ VALIDAÇÃO COMPLETA (10 minutos)

**Arquivo**: `validacao_final.sql`

Execute **uma query por vez** (não todas juntas). 12 queries detalhadas incluindo:
- Estrutura das tabelas
- Valores de DEC/FEC
- Validação de totais
- Exemplos de uso

## ⚡ Quick Test - Execute Agora

Copie e cole no Databricks SQL Editor:

```sql
-- Teste 1: Tabelas existem?
SHOW TABLES IN grid_dev.gold;
-- Deve mostrar 5 objetos

-- Teste 2: Metric view funciona?
SELECT `Conjunto`, MEASURE(`DEC`), MEASURE(`FEC`)
FROM grid_dev.gold.continuidade_metricas
GROUP BY `Conjunto`
LIMIT 5;
-- Deve retornar 5-6 linhas com números
```

**Se estes 2 testes passarem → 90% está OK!**

## 📊 Valores Esperados

| Query | Valor Esperado | O Que Significa |
|-------|----------------|-----------------|
| DEC mensal | 0.05 a 1.3 horas | Normal para 1 mês, 1 conjunto |
| FEC mensal | 0.1 a 0.6 vezes | Normal para 1 mês, 1 conjunto |
| Total interrupções | 1.073 eventos | Total no dataset |
| Prioridades | 3 categorias | alta, media, baixa |
| Riscos | 3 níveis | alto, medio, baixo |

## ⚠️ Sinais de Problema

| Sintoma | Provável Causa | Solução |
|---------|----------------|---------|
| DEC > 10 horas (1 mês) | Denominador errado | Verificar se usa `total_ucs` |
| Sem prioridade "alta" | Limiares mal configurados | Ajustar `limiar_queda_uc_pct` |
| Metric view não existe | Não executou o SQL | Executar `DEPLOY_FINAL.md` seção metric view |
| Erro "TABLE_OR_VIEW_NOT_FOUND" | Nome errado ou schema errado | Verificar `grid_dev.gold.nome_tabela` |

## 🐛 Troubleshooting de Erros Comuns

### Erro: "TABLE_OR_VIEW_NOT_FOUND"
```sql
-- Verifique o schema correto
SHOW SCHEMAS IN grid_dev;

-- Verifique as tabelas
SHOW TABLES IN grid_dev.gold;
```

### Erro: "MEASURE not found"
Significa que a metric view não foi criada. Execute:
```sql
-- Ver em DEPLOY_FINAL.md a seção de criação da metric view
-- Copie e execute o CREATE OR REPLACE VIEW ... WITH METRICS ...
```

### Erro: "Syntax error near DESCRIBE VIEW"
Use `DESCRIBE TABLE` ao invés de `DESCRIBE VIEW`:
```sql
DESCRIBE TABLE grid_dev.gold.continuidade_metricas;
```

## ✅ Checklist Mínimo (3 queries)

Execute estas 3 queries. Se passarem, está OK:

```sql
-- ✅ 1. Tabelas existem?
SHOW TABLES IN grid_dev.gold;

-- ✅ 2. Metric view calcula DEC?
SELECT MEASURE(`DEC`) AS dec 
FROM grid_dev.gold.continuidade_metricas 
LIMIT 1;

-- ✅ 3. Sem palavras proibidas?
SELECT COUNT(*) AS erros
FROM grid_dev.gold.prioridade_inspecao_uc
WHERE motivo_observado LIKE '%fraude%';
-- Deve retornar 0
```

## 🎉 Próximo Passo

Depois de validar, você pode:

1. **Criar Dashboard**: Use a metric view em visualizações
2. **Testar Agente**: Faça perguntas em português sobre DEC/FEC
3. **Documentar**: Anote os valores encontrados no seu ambiente
4. **Avançar**: Ir para o Prompt 05 do projeto

---

**Arquivos de Validação Disponíveis:**
- `teste_rapido.sql` → 5 queries essenciais ⭐
- `validacao_simples.sql` → 10 queries focadas (novo)
- `validacao_final.sql` → 12 queries completas
- `CHECKLIST_VALIDACAO.md` → 20 pontos de verificação

**Escolha um e execute!** 🚀
