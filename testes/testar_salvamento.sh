#!/usr/bin/env bash
set -euo pipefail

TEST_DB="test_analises.db"
PASSED=true

# ─── Helper para escapar SQL ───
sqlite_escape() {
    printf '%s' "$1" | sed "s/'/''/g"
}

# ─── Limpar banco de teste anterior ───
rm -f "$TEST_DB"

echo "=== Teste unitário: Salvamento no SQLite ==="
echo ""

# ─── Teste 1: Criação da tabela ───
echo "[1] Criando tabela..."
sqlite3 "$TEST_DB" "CREATE TABLE IF NOT EXISTS analises (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    nome_arquivo TEXT NOT NULL,
    conteudo_arquivo TEXT NOT NULL,
    interpretacao TEXT NOT NULL,
    data_hora TEXT NOT NULL,
    hash_arquivo TEXT NOT NULL
);"
sqlite3 "$TEST_DB" "ALTER TABLE analises ADD COLUMN hash_arquivo TEXT NOT NULL DEFAULT '';" 2>/dev/null || true
sqlite3 "$TEST_DB" "ALTER TABLE analises ADD COLUMN ignorado INTEGER DEFAULT 0;" 2>/dev/null || true
sqlite3 "$TEST_DB" "ALTER TABLE analises ADD COLUMN motivo TEXT DEFAULT '';" 2>/dev/null || true

table_count=$(sqlite3 "$TEST_DB" "SELECT count(*) FROM sqlite_master WHERE type='table' AND name='analises';")
if [ "$table_count" = "1" ]; then
    echo "  ✓ Tabela criada com sucesso"
else
    echo "  ✗ Erro ao criar tabela"
    PASSED=false
fi

# ─── Teste 2: Inserção de registro com aspas simples ───
echo "[2] Inserindo registro (com aspas simples no conteúdo)..."
TEST_FILE="dir_teste/test's_file.py"
TEST_CONTENT="print('hello world'); x = 1"
TEST_INTERPRETATION="O código imprime 'hello world' e atribui x = 1"
TEST_DATA_HORA=$(date '+%Y-%m-%d %H:%M:%S')
TEST_HASH=$(echo -n "$TEST_CONTENT" | sha256sum | awk '{print $1}')

nome_esc=$(sqlite_escape "$TEST_FILE")
content_esc=$(sqlite_escape "$TEST_CONTENT")
interp_esc=$(sqlite_escape "$TEST_INTERPRETATION")

sqlite3 "$TEST_DB" "INSERT INTO analises (nome_arquivo, conteudo_arquivo, interpretacao, data_hora, hash_arquivo, ignorado, motivo) VALUES ('$nome_esc', '$content_esc', '$interp_esc', '$TEST_DATA_HORA', '$TEST_HASH', 0, 'negocio');"

row_count=$(sqlite3 "$TEST_DB" "SELECT count(*) FROM analises;")
if [ "$row_count" = "1" ]; then
    echo "  ✓ Registro inserido com sucesso"
else
    echo "  ✗ Erro ao inserir registro (contagem=$row_count)"
    PASSED=false
fi

# ─── Teste 3: Leitura e verificação dos campos ───
echo "[3] Verificando campos persistidos..."
RESULT=$(sqlite3 "$TEST_DB" "SELECT nome_arquivo, conteudo_arquivo, interpretacao, data_hora, hash_arquivo, ignorado, motivo FROM analises WHERE id=1;")
IFS='|' read -r r_nome r_conteudo r_interp r_data r_hash r_ignorado r_motivo <<< "$RESULT"

if [ "$r_nome" != "$TEST_FILE" ]; then
    echo "  ✗ Erro: nome_arquivo esperado='$TEST_FILE' obtido='$r_nome'"
    PASSED=false
fi

if [ "$r_conteudo" != "$TEST_CONTENT" ]; then
    echo "  ✗ Erro: conteudo_arquivo esperado='$TEST_CONTENT' obtido='$r_conteudo'"
    PASSED=false
fi

if [ "$r_interp" != "$TEST_INTERPRETATION" ]; then
    echo "  ✗ Erro: interpretacao esperado='$TEST_INTERPRETATION' obtido='$r_interp'"
    PASSED=false
fi

if [ "$r_data" != "$TEST_DATA_HORA" ]; then
    echo "  ✗ Erro: data_hora esperado='$TEST_DATA_HORA' obtido='$r_data'"
    PASSED=false
fi

if [ "$r_hash" != "$TEST_HASH" ]; then
    echo "  ✗ Erro: hash_arquivo esperado='$TEST_HASH' obtido='$r_hash'"
    PASSED=false
fi

if [ "$r_ignorado" != "0" ]; then
    echo "  ✗ Erro: ignorado esperado='0' obtido='$r_ignorado'"
    PASSED=false
fi

if [ "$r_motivo" != "negocio" ]; then
    echo "  ✗ Erro: motivo esperado='negocio' obtido='$r_motivo'"
    PASSED=false
fi

if $PASSED; then
    echo "  ✓ Todos os campos verificados com sucesso"
fi

# ─── Teste 4: Auto-incremento ───
echo "[4] Verificando auto-incremento..."
sqlite3 "$TEST_DB" "INSERT INTO analises (nome_arquivo, conteudo_arquivo, interpretacao, data_hora, hash_arquivo, ignorado, motivo) VALUES ('file2.py', 'x=2', 'atribuicao', '$TEST_DATA_HORA', 'abc123', 0, 'negocio');"
id2=$(sqlite3 "$TEST_DB" "SELECT id FROM analises WHERE nome_arquivo='file2.py';")
if [ "$id2" = "2" ]; then
    echo "  ✓ Auto-incremento funcionando (id=2)"
else
    echo "  ✗ Erro no auto-incremento (esperado=2, obtido=$id2)"
    PASSED=false
fi

# ─── Teste 5: Inserção de arquivo ignorado ───
echo "[5] Inserindo arquivo ignorado (framework)..."
IGN_FILE="node_modules/react/index.js"
IGN_INTERP="Arquivo ignorado: framework"
IGN_DATA_HORA=$(date '+%Y-%m-%d %H:%M:%S')

ign_nome_esc=$(sqlite_escape "$IGN_FILE")
ign_interp_esc=$(sqlite_escape "$IGN_INTERP")

sqlite3 "$TEST_DB" "INSERT INTO analises (nome_arquivo, conteudo_arquivo, interpretacao, data_hora, hash_arquivo, ignorado, motivo) VALUES ('$ign_nome_esc', '', '$ign_interp_esc', '$IGN_DATA_HORA', '', 1, 'framework');"

ign_count=$(sqlite3 "$TEST_DB" "SELECT count(*) FROM analises WHERE ignorado=1;")
if [ "$ign_count" = "1" ]; then
    echo "  ✓ Arquivo ignorado inserido com sucesso"
else
    echo "  ✗ Erro ao inserir arquivo ignorado (contagem=$ign_count)"
    PASSED=false
fi

IGN_RESULT=$(sqlite3 "$TEST_DB" "SELECT nome_arquivo, conteudo_arquivo, interpretacao, ignorado, motivo FROM analises WHERE ignorado=1;")
IFS='|' read -r i_nome i_conteudo i_interp i_ignorado i_motivo <<< "$IGN_RESULT"

if [ "$i_nome" != "$IGN_FILE" ]; then
    echo "  ✗ Erro: nome_arquivo esperado='$IGN_FILE' obtido='$i_nome'"
    PASSED=false
fi

if [ "$i_conteudo" != "" ]; then
    echo "  ✗ Erro: conteudo_arquivo esperado='' obtido='$i_conteudo'"
    PASSED=false
fi

if [ "$i_ignorado" != "1" ]; then
    echo "  ✗ Erro: ignorado esperado='1' obtido='$i_ignorado'"
    PASSED=false
fi

if [ "$i_motivo" != "framework" ]; then
    echo "  ✗ Erro: motivo esperado='framework' obtido='$i_motivo'"
    PASSED=false
fi

echo "  ✓ Campos do arquivo ignorado verificados"

# ─── Teste 6: Inserção de arquivo ignorado (configuracao) ───
echo "[6] Inserindo arquivo ignorado (configuracao)..."
IGN2_FILE="vite.config.ts"
IGN2_INTERP="Arquivo ignorado: configuracao"

ign2_nome_esc=$(sqlite_escape "$IGN2_FILE")
ign2_interp_esc=$(sqlite_escape "$IGN2_INTERP")

sqlite3 "$TEST_DB" "INSERT INTO analises (nome_arquivo, conteudo_arquivo, interpretacao, data_hora, hash_arquivo, ignorado, motivo) VALUES ('$ign2_nome_esc', '', '$ign2_interp_esc', '$IGN_DATA_HORA', '', 1, 'configuracao');"

ign2_motivo=$(sqlite3 "$TEST_DB" "SELECT motivo FROM analises WHERE nome_arquivo='$ign2_nome_esc';")
if [ "$ign2_motivo" = "configuracao" ]; then
    echo "  ✓ Arquivo de configuracao ignorado com motivo correto"
else
    echo "  ✗ Erro: motivo esperado='configuracao' obtido='$ign2_motivo'"
    PASSED=false
fi

# ─── Teste 7: Inserção de arquivo ignorado (biblioteca) ───
echo "[7] Inserindo arquivo ignorado (biblioteca)..."
IGN3_FILE="package.json"
IGN3_INTERP="Arquivo ignorado: biblioteca"

ign3_nome_esc=$(sqlite_escape "$IGN3_FILE")
ign3_interp_esc=$(sqlite_escape "$IGN3_INTERP")

sqlite3 "$TEST_DB" "INSERT INTO analises (nome_arquivo, conteudo_arquivo, interpretacao, data_hora, hash_arquivo, ignorado, motivo) VALUES ('$ign3_nome_esc', '', '$ign3_interp_esc', '$IGN_DATA_HORA', '', 1, 'biblioteca');"

ign3_motivo=$(sqlite3 "$TEST_DB" "SELECT motivo FROM analises WHERE nome_arquivo='$ign3_nome_esc';")
if [ "$ign3_motivo" = "biblioteca" ]; then
    echo "  ✓ Arquivo de biblioteca ignorado com motivo correto"
else
    echo "  ✗ Erro: motivo esperado='biblioteca' obtido='$ign3_motivo'"
    PASSED=false
fi

# ─── Teste 8: Contagem total de ignorados ───
echo "[8] Verificando contagem total de ignorados..."
total_ignorados=$(sqlite3 "$TEST_DB" "SELECT count(*) FROM analises WHERE ignorado=1;")
if [ "$total_ignorados" = "3" ]; then
    echo "  ✓ Contagem de ignorados correta (3)"
else
    echo "  ✗ Erro: contagem esperada='3' obtido='$total_ignorados'"
    PASSED=false
fi

total_negocio=$(sqlite3 "$TEST_DB" "SELECT count(*) FROM analises WHERE ignorado=0;")
if [ "$total_negocio" = "2" ]; then
    echo "  ✓ Contagem de negocio correta (2)"
else
    echo "  ✗ Erro: contagem esperada='2' obtido='$total_negocio'"
    PASSED=false
fi

# ─── Limpeza ───
rm -f "$TEST_DB"

# ─── Resultado final ───
echo ""
if $PASSED; then
    echo "=== Teste APROVADO ==="
    exit 0
else
    echo "=== Teste REPROVADO ==="
    exit 1
fi
