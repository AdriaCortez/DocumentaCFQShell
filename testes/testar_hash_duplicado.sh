#!/usr/bin/env bash
set -euo pipefail

TEST_DB="test_hash_duplicado.db"
TEST_DIR="/tmp/test_hash_duplicado_$$"
PASSED=true

cleanup() {
    rm -rf "$TEST_DIR"
    rm -f "$TEST_DB"
}
trap cleanup EXIT

sqlite_escape() {
    printf '%s' "$1" | sed "s/'/''/g"
}

mkdir -p "$TEST_DIR"

echo "=== Teste: Hash duplicado — verificação pré-análise ==="
echo ""

# ─── Teste 1: Criar banco e tabela ───
echo "[1] Criando banco e tabela de teste..."
sqlite3 "$TEST_DB" "CREATE TABLE IF NOT EXISTS analises (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    nome_arquivo TEXT NOT NULL,
    conteudo_arquivo TEXT NOT NULL,
    interpretacao TEXT NOT NULL,
    data_hora TEXT NOT NULL,
    hash_arquivo TEXT NOT NULL
);"
echo "  ✓ Banco criado"

# ─── Teste 2: Criar arquivo A e inserir no banco ───
echo "[2] Criando arquivo A e inserindo análise prévia..."
ARQ_A="$TEST_DIR/arquivo_a.py"
echo 'print("hello world from A"); x = 42' > "$ARQ_A"
HASH_A=$(sha256sum "$ARQ_A" | awk '{print $1}')
DATA_HORA=$(date '+%Y-%m-%d %H:%M:%S')

nome_esc=$(sqlite_escape "$ARQ_A")
conteudo_esc=$(sqlite_escape "$(cat "$ARQ_A")")
interp_esc=$(sqlite_escape "Análise prévia do arquivo A")
hash_esc=$(sqlite_escape "$HASH_A")

sqlite3 "$TEST_DB" "INSERT INTO analises (nome_arquivo, conteudo_arquivo, interpretacao, data_hora, hash_arquivo)
    VALUES ('$nome_esc', '$conteudo_esc', '$interp_esc', '$DATA_HORA', '$hash_esc');"

row_count=$(sqlite3 "$TEST_DB" "SELECT count(*) FROM analises WHERE hash_arquivo='$hash_esc';")
if [ "$row_count" = "1" ]; then
    echo "  ✓ Registro inserido (hash: ${HASH_A:0:12}...)"
else
    echo "  ✗ Erro ao inserir registro"
    PASSED=false
fi

# ─── Teste 3: Simular verificação — arquivo A (hash existe no banco) ───
echo "[3] Verificando arquivo A (hash deve existir no banco)..."
HASH_A_REVALIDADO=$(sha256sum "$ARQ_A" | awk '{print $1}')
hash_esc=$(sqlite_escape "$HASH_A_REVALIDADO")
existe=$(sqlite3 "$TEST_DB" "SELECT count(*) FROM analises WHERE hash_arquivo='$hash_esc';")

if [ "$existe" -gt 0 ]; then
    echo "  ✓ Arquivo A detectado como já analisado (seria pulado)"
else
    echo "  ✗ Erro: arquivo A deveria ser detectado como já analisado"
    PASSED=false
fi

# ─── Teste 4: Simular verificação — arquivo B (hash NÃO existe no banco) ───
echo "[4] Criando arquivo B e verificando (hash NÃO deve existir)..."
ARQ_B="$TEST_DIR/arquivo_b.js"
echo 'console.log("hello from B"); let y = 99;' > "$ARQ_B"
HASH_B=$(sha256sum "$ARQ_B" | awk '{print $1}')
hash_esc=$(sqlite_escape "$HASH_B")
existe=$(sqlite3 "$TEST_DB" "SELECT count(*) FROM analises WHERE hash_arquivo='$hash_esc';")

if [ "$existe" -eq 0 ]; then
    echo "  ✓ Arquivo B detectado como NÃO analisado (seria processado)"
else
    echo "  ✗ Erro: arquivo B não deveria existir no banco"
    PASSED=false
fi

# ─── Teste 5: Simular cenário real com múltiplos arquivos ───
echo "[5] Simulando mix de arquivos (1 já analisado, 2 novos)..."
ARQ_C="$TEST_DIR/arquivo_c.go"
echo 'package main; func main() {}' > "$ARQ_C"

declare -a arquivos=("$ARQ_A" "$ARQ_B" "$ARQ_C")
declare -a pendentes=()
pulados=0

for file in "${arquivos[@]}"; do
    h=$(sha256sum "$file" | awk '{print $1}')
    he=$(sqlite_escape "$h")
    e=$(sqlite3 "$TEST_DB" "SELECT count(*) FROM analises WHERE hash_arquivo='$he';")
    if [ "$e" -gt 0 ]; then
        echo "  ∟ Pulando (já analisado): $(basename "$file")"
        pulados=$((pulados + 1))
    else
        pendentes+=("$file")
    fi
done

if [ "$pulados" = "1" ] && [ "${#pendentes[@]}" = "2" ]; then
    echo "  ✓ 1 arquivo pulado, 2 pendentes — filtragem correta"
else
    echo "  ✗ Erro: esperado 1 pulado/2 pendentes, obtido $pulados/${#pendentes[@]}"
    PASSED=false
fi

# ─── Teste 6: Verificar que hash muda quando conteúdo muda ───
echo "[6] Verificando que hash muda com conteúdo diferente..."
ARQ_A_V2="$TEST_DIR/arquivo_a.py"
echo 'print("conteudo modificado"); x = 99' > "$ARQ_A_V2"
HASH_A_V2=$(sha256sum "$ARQ_A_V2" | awk '{print $1}')

if [ "$HASH_A_V2" != "$HASH_A" ]; then
    echo "  ✓ Hash modificado detectado (arquivo editado seria reanalisado)"
else
    echo "  ✗ Erro: hash deveria ser diferente após modificação"
    PASSED=false
fi

# ─── Resultado final ───
echo ""
if $PASSED; then
    echo "=== Teste APROVADO ==="
    exit 0
else
    echo "=== Teste REPROVADO ==="
    exit 1
fi
