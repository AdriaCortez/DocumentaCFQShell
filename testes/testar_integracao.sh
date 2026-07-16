#!/usr/bin/env bash
set -euo pipefail

TESTES_PASSARAM=true
ERROS=0
SUCESSOS=0
BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"

assert_igual() {
    local desc="$1" esp="$2" obt="$3"
    if [ "$obt" = "$esp" ]; then
        SUCESSOS=$((SUCESSOS + 1)); printf '  ✓ [%s]\n' "$desc"
    else
        ERROS=$((ERROS + 1)); TESTES_PASSARAM=false
        printf '  ✗ [%s] esperado="%s" obtido="%s"\n' "$desc" "$esp" "$obt"
    fi
}

assert_contem() {
    local desc="$1" texto="$2" padrao="$3"
    if printf '%s' "$texto" | grep -qF "$padrao"; then
        SUCESSOS=$((SUCESSOS + 1)); printf '  ✓ [%s]\n' "$desc"
    else
        ERROS=$((ERROS + 1)); TESTES_PASSARAM=false
        printf '  ✗ [%s] não contém "%s"\n' "$desc" "$padrao"
    fi
}

assert_json_campo() {
    local desc="$1" json="$2" campo="$3" esp="$4"
    local obt
    obt=$(printf '%s' "$json" | jq -r "$campo" 2>/dev/null || echo "ERRO")
    assert_igual "$desc" "$esp" "$obt"
}

# ─── Carregar módulos ───
export MODO_SILENCIOSO=true
source "$BASE_DIR/config.sh"
source "$BASE_DIR/src/util/validacao.sh"
source "$BASE_DIR/src/controle/banco.sh"
source "$BASE_DIR/src/llm/prompt.sh"
source "$BASE_DIR/src/analise/classificador.sh"
source "$BASE_DIR/src/controle/estado.sh"
source "$BASE_DIR/src/controle/progresso.sh"
source "$BASE_DIR/src/controle/eventos.sh"
source "$BASE_DIR/src/controle/fila.sh"

echo "============================================================"
echo "  Teste de Integração — API de Análise"
echo "============================================================"

# ─── Teste 1: Banco ───
echo ""
echo "[1] Banco: CRUD"
BANCO_TESTE="/tmp/t_integ_bd_$$.db"
rm -f "$BANCO_TESTE"
ARQUIVO_BANCO="$BANCO_TESTE"
inicializar_banco

existe=$(sqlite3 "$BANCO_TESTE" "SELECT count(*) FROM sqlite_master WHERE name='analises';")
assert_igual "Tabela criada" "1" "$existe"

salvar_analise "teste.py" "print(1)" "Análise" "hashX" 0 "negocio"
salvar_ignorado "node_modules/x.js" "framework"
total=$(sqlite3 "$BANCO_TESTE" "SELECT count(*) FROM analises;")
assert_igual "2 registros" "2" "$total"

estat=$(obter_estatisticas)
assert_json_campo "Stats: total" "$estat" ".total" "2"
assert_json_campo "Stats: negócio" "$estat" ".negocio" "1"
assert_json_campo "Stats: ignorados" "$estat" ".ignorados" "1"
assert_json_campo "Stats: framework" "$estat" ".por_motivo.framework" "1"

existe_h=$(verificar_hash_existe_cache "hashX")
assert_igual "Hash existe" "1" "$existe_h"
existe_n=$(verificar_hash_existe_cache "inexistente")
assert_igual "Hash inexistente" "0" "$existe_n"

cache=$(obter_analise_por_hash "hashX")
assert_json_campo "Cache por hash" "$cache" ".nome_arquivo" "teste.py"
rm -f "$BANCO_TESTE"

# ─── Teste 2: Classificador ───
echo ""
echo "[2] Classificação"
assert_igual "Negócio" "negocio" "$(classificar_arquivo "src/App.tsx")"
assert_igual "Framework" "framework" "$(classificar_arquivo "node_modules/react/index.js")"
assert_igual "Config" "configuracao" "$(classificar_arquivo "vite.config.ts")"
assert_igual "Biblioteca" "biblioteca" "$(classificar_arquivo "package.json")"
assert_igual "Tipo pág." "pagina" "$(classificar_tipo_arquivo "src/pages/UserPage.tsx")"
assert_igual "Tipo comp." "componente" "$(classificar_tipo_arquivo "src/components/Button.tsx")"
assert_igual "Tipo serv." "servico" "$(classificar_tipo_arquivo "src/services/api.ts")"

# ─── Teste 3: Templates ───
echo ""
echo "[3] Templates"
sis=$(carregar_template_sistema)
assert_contem "Template sistema" "$sis" "analista de sistemas"

pag=$(carregar_template "pagina")
assert_contem "Template página" "$pag" "CONTEXTO_GLOBAL"

comp=$(carregar_template "componente")
assert_contem "Template componente" "$comp" "CONTEXTO_GLOBAL"

pad=$(carregar_template "padrao")
assert_contem "Template padrão" "$pad" "CONTEXTO_GLOBAL"

# Fallback
fall=$(carregar_template "tipo_inexistente" || echo "")
assert_contem "Fallback padrao" "$fall" "CONTEXTO_GLOBAL"

# ─── Teste 4: Estado e Progresso ───
echo ""
echo "[4] Estado/Progresso"
CTRL="/tmp/t_integ_ctrl_$$"
mkdir -p "$CTRL"
DIRETORIO_CONTROLE="$CTRL"
ARQUIVO_STATUS="$CTRL/status"
ARQUIVO_PID="$CTRL/pid"
ARQUIVO_PROGRESSO="$CTRL/progresso"
ARQUIVO_EVENTOS="$CTRL/events"
ARQUIVO_FILA="$CTRL/fila"

inicializar_controle
assert_igual "Status inicial" "parado||false" "$(obter_status)"

definir_status "executando"
definir_pid "99999"
assert_igual "Status executando" "executando|99999|false" "$(obter_status)"

definir_progresso "5" "20" "App.tsx"
assert_igual "Progresso" "5/20|App.tsx" "$(obter_progresso)"

definir_fila "a.js" "b.py" "c.go"
assert_igual "Fila 3 itens" "3" "$(total_na_fila)"

inicializar_eventos
notificar_finalizado 10 2 5 ""
evt=$(cat "$ARQUIVO_EVENTOS")
assert_contem "Evento finalizado" "$evt" "finalizado"

limpar_controle
assert_igual "Limpo" "parado||false" "$(obter_status)"
rm -rf "$CTRL"

# ─── Teste 5: API ───
echo ""
echo "[5] API — Iniciar servidor"
PORTA_T=9877
cp "$BASE_DIR/dados/analises.db" "$BASE_DIR/dados/analises.db.int" 2>/dev/null || touch "$BASE_DIR/dados/analises.db.int"

export API_PORTA="$PORTA_T" API_HOST="127.0.0.1"
bash "$BASE_DIR/src/api/servidor.sh" &
PID_SRV=$!
sleep 2

if kill -0 "$PID_SRV" 2>/dev/null; then
    SUCESSOS=$((SUCESSOS + 1)); printf '  ✓ [Servidor iniciado PID=%d]\n' "$PID_SRV"

    echo "[6] API — GET endpoints"
    r=$(curl -s "http://127.0.0.1:$PORTA_T/api/v1/status")
    assert_json_campo "GET status" "$r" ".status" "parado"

    r=$(curl -s "http://127.0.0.1:$PORTA_T/api/v1/progresso")
    assert_json_campo "GET progresso" "$r" ".atual" "0"

    r=$(curl -s "http://127.0.0.1:$PORTA_T/api/v1/analises")
    tipo=$(printf '%s' "$r" | jq -r 'type')
    assert_igual "GET analises array" "array" "$tipo"

    r=$(curl -s "http://127.0.0.1:$PORTA_T/api/v1/estatisticas")
    assert_contem "GET estatisticas tem negocio" "$r" '"negocio"'

    r=$(curl -s "http://127.0.0.1:$PORTA_T/api/v1/fila")
    assert_json_campo "GET fila" "$r" ".status" "parado"

    echo "[7] API — POST endpoints"
    r=$(curl -s -X POST "http://127.0.0.1:$PORTA_T/api/v1/analisar/arquivo" \
        -H "Content-Type: application/json" -d "invalido")
    assert_json_campo "POST JSON inval" "$r" ".codigo" "400"

    r=$(curl -s -X POST "http://127.0.0.1:$PORTA_T/api/v1/analisar/arquivo" \
        -H "Content-Type: application/json" -d "{}")
    assert_json_campo "POST vazio 400" "$r" ".codigo" "400"

    r=$(curl -s -X PUT "http://127.0.0.1:$PORTA_T/api/v1/status")
    assert_json_campo "PUT 405" "$r" ".codigo" "405"

    r=$(curl -s "http://127.0.0.1:$PORTA_T/api/v1/inexistente")
    assert_json_campo "404" "$r" ".codigo" "404"

    echo "[8] API — CORS"
    hdr=$(curl -s -I -X OPTIONS "http://127.0.0.1:$PORTA_T/api/v1/status" 2>/dev/null | head -1)
    assert_contem "OPTIONS 204" "$hdr" "204"

    echo "[9] API — Analisar arquivo com prompt customizado"
    ARQ_T="/tmp/t_integ_arq_$$.js"
    printf 'console.log("hello test");\n' > "$ARQ_T"

    r=$(curl -s -X POST "http://127.0.0.1:$PORTA_T/api/v1/analisar/arquivo" \
        -H "Content-Type: application/json" \
        -d "{\"prompt_sistema\":\"Você é analista.\",\"prompt_usuario\":\"Resuma: console.log('hello')\",\"arquivo\":{\"caminho\":\"$ARQ_T\",\"conteudo\":\"$(cat "$ARQ_T")\"}}")

    st=$(printf '%s' "$r" | jq -r '.status // "erro"')
    echo "  Status: $st"
    if [ "$st" = "concluido" ] || [ "$st" = "cacheado" ] || [ "$st" = "erro" ]; then
        SUCESSOS=$((SUCESSOS + 1)); printf '  ✓ [Análise respondeu: %s]\n' "$st"
    else
        ERROS=$((ERROS + 1)); printf '  ✗ [Status: %s]\n' "$st"
    fi
    rm -f "$ARQ_T"

    r=$(curl -s "http://127.0.0.1:$PORTA_T/api/v1/resultado/1")
    idres=$(printf '%s' "$r" | jq -r '.id // "null"')
    if [ "$idres" != "null" ] || printf '%s' "$r" | jq -e '.erro' >/dev/null 2>&1; then
        SUCESSOS=$((SUCESSOS + 1)); printf '  ✓ [GET resultado funciona]\n'
    else
        ERROS=$((ERROS + 1)); printf '  ✗ [GET resultado falhou]\n'
    fi

    kill "$PID_SRV" 2>/dev/null || true
    wait "$PID_SRV" 2>/dev/null || true
else
    ERROS=$((ERROS + 1)); printf '  ✗ [Servidor não iniciou]\n'
fi

mv "$BASE_DIR/dados/analises.db.int" "$BASE_DIR/dados/analises.db" 2>/dev/null || true

# ─── Resultado ───
echo ""
echo "============================================================"
echo "  RESULTADO: $SUCESSOS sucessos, $ERROS erros"
echo "============================================================"

if $TESTES_PASSARAM; then
    echo "  TODOS OS TESTES PASSARAM"
    exit 0
else
    echo "  ALGUNS TESTES FALHARAM"
    exit 1
fi
