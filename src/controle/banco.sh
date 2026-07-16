#!/usr/bin/env bash
set -euo pipefail

# ─── Operações do banco SQLite ───

executar_sqlite() {
    sqlite3 -cmd ".output /dev/null" -cmd "PRAGMA journal_mode=WAL;" -cmd "PRAGMA busy_timeout=30000;" -cmd ".output stdout" "$ARQUIVO_BANCO" "$@"
}

executar_sqlite_json() {
    sqlite3 -json -cmd ".output /dev/null" -cmd "PRAGMA journal_mode=WAL;" -cmd "PRAGMA busy_timeout=30000;" -cmd ".output stdout" "$ARQUIVO_BANCO" "$@"
}

inicializar_banco() {
    executar_sqlite "CREATE TABLE IF NOT EXISTS analises (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nome_arquivo TEXT NOT NULL,
        conteudo_arquivo TEXT NOT NULL,
        interpretacao TEXT NOT NULL,
        data_hora TEXT NOT NULL,
        hash_arquivo TEXT NOT NULL
    );"
    executar_sqlite "ALTER TABLE analises ADD COLUMN hash_arquivo TEXT NOT NULL DEFAULT '';" 2>/dev/null || true
    executar_sqlite "ALTER TABLE analises ADD COLUMN ignorado INTEGER DEFAULT 0;" 2>/dev/null || true
    executar_sqlite "ALTER TABLE analises ADD COLUMN motivo TEXT DEFAULT '';" 2>/dev/null || true
    executar_sqlite "ALTER TABLE analises ADD COLUMN projeto_id INTEGER DEFAULT NULL;" 2>/dev/null || true

    executar_sqlite "CREATE TABLE IF NOT EXISTS projetos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nome TEXT NOT NULL,
        descricao TEXT DEFAULT '',
        data_criacao TEXT NOT NULL,
        data_atualizacao TEXT NOT NULL,
        status TEXT DEFAULT 'criado',
        total_arquivos INTEGER DEFAULT 0,
        arquivos_analisados INTEGER DEFAULT 0,
        diretorio_upload TEXT DEFAULT ''
    );"

    executar_sqlite "CREATE TABLE IF NOT EXISTS projetos_arquivos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        projeto_id INTEGER NOT NULL,
        nome TEXT NOT NULL,
        caminho_relativo TEXT NOT NULL,
        tamanho INTEGER DEFAULT 0,
        status TEXT DEFAULT 'pendente',
        analise_id INTEGER DEFAULT NULL,
        FOREIGN KEY (projeto_id) REFERENCES projetos(id) ON DELETE CASCADE
    );"

    executar_sqlite "CREATE INDEX IF NOT EXISTS idx_analises_projeto ON analises(projeto_id);" 2>/dev/null || true
    executar_sqlite "CREATE INDEX IF NOT EXISTS idx_projetos_arquivos_projeto ON projetos_arquivos(projeto_id);" 2>/dev/null || true

    executar_sqlite "CREATE TABLE IF NOT EXISTS analises_globais (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        projeto_id INTEGER NOT NULL DEFAULT 0,
        interpretacao TEXT NOT NULL,
        arvore_arquivos TEXT NOT NULL,
        data_hora TEXT NOT NULL
    );" 2>/dev/null || true

    executar_sqlite "ALTER TABLE analises ADD COLUMN user_id INTEGER DEFAULT 0;" 2>/dev/null || true

    executar_sqlite "ALTER TABLE projetos ADD COLUMN user_id INTEGER DEFAULT 0;" 2>/dev/null || true

    executar_sqlite "ALTER TABLE analises_globais ADD COLUMN user_id INTEGER DEFAULT 0;" 2>/dev/null || true

    executar_sqlite "CREATE INDEX IF NOT EXISTS idx_projetos_user ON projetos(user_id);" 2>/dev/null || true

    executar_sqlite "CREATE INDEX IF NOT EXISTS idx_analises_globais_projeto ON analises_globais(projeto_id);" 2>/dev/null || true
}

salvar_analise() {
    local nome_arquivo="$1"
    local conteudo="$2"
    local interpretacao="$3"
    local hash="$4"
    local ignorado="$5"
    local motivo="$6"
    local projeto_id="${7:-}"
    local user_id="${8:-0}"

    local data_hora nome_esc content_esc interp_esc hash_esc
    data_hora=$(date '+%Y-%m-%d %H:%M:%S')
    nome_esc=$(escapar_sql "$nome_arquivo")
    content_esc=$(escapar_sql "$conteudo")
    interp_esc=$(escapar_sql "$interpretacao")
    hash_esc=$(escapar_sql "$hash")

    local projeto_clause
    if [ -n "$projeto_id" ] && [ "$projeto_id" != "null" ]; then
        projeto_clause="$projeto_id"
    else
        projeto_clause="NULL"
    fi

    executar_sqlite \
        "INSERT INTO analises (nome_arquivo, conteudo_arquivo, interpretacao, data_hora, hash_arquivo, ignorado, motivo, projeto_id, user_id)
         VALUES ('$nome_esc', '$content_esc', '$interp_esc', '$data_hora', '$hash_esc', $ignorado, '$motivo', $projeto_clause, $user_id);"
}

obter_ultimo_id() {
    executar_sqlite "SELECT last_insert_rowid();" 2>/dev/null || echo 0
}

verificar_hash_existe() {
    local hash="$1"
    local user_id="${2:-}"
    local hash_esc
    hash_esc=$(escapar_sql "$hash")

    local user_clause=""
    if [ -n "$user_id" ] && [ "$user_id" != "0" ]; then
        user_clause="AND user_id=$user_id"
    fi

    local existe
    existe=$(executar_sqlite \
        "SELECT count(*) FROM analises WHERE hash_arquivo='$hash_esc' AND ignorado=0 $user_clause;" 2>/dev/null || echo 0)
    [ "$existe" -gt 0 ]
}

verificar_hash_existe_cache() {
    local hash="$1"
    local user_id="${2:-}"
    local hash_esc
    hash_esc=$(escapar_sql "$hash")

    local user_clause=""
    if [ -n "$user_id" ] && [ "$user_id" != "0" ]; then
        user_clause="AND user_id=$user_id"
    fi

    local existe
    existe=$(executar_sqlite \
        "SELECT count(*) FROM analises WHERE hash_arquivo='$hash_esc' AND ignorado=0 $user_clause;" 2>/dev/null || echo 0)
    echo "$existe"
}

obter_analise_por_hash() {
    local hash="$1"
    local user_id="${2:-}"
    local hash_esc
    hash_esc=$(escapar_sql "$hash")

    local user_clause=""
    if [ -n "$user_id" ] && [ "$user_id" != "0" ]; then
        user_clause="AND user_id=$user_id"
    fi

    executar_sqlite_json \
        "SELECT id, nome_arquivo, interpretacao, data_hora, hash_arquivo
         FROM analises WHERE hash_arquivo='$hash_esc' AND ignorado=0 $user_clause
         ORDER BY id DESC LIMIT 1;" 2>/dev/null | jq '.[0] // null' 2>/dev/null || echo "null"
}

obter_analises() {
    executar_sqlite_json \
        "SELECT id, nome_arquivo, data_hora, ignorado, motivo FROM analises ORDER BY id DESC LIMIT 100;" \
        2>/dev/null || echo "[]"
}

obter_analise_por_id() {
    local id="$1"
    executar_sqlite_json \
        "SELECT * FROM analises WHERE id=$id;" \
        2>/dev/null | jq '.[0] // null' 2>/dev/null || echo "null"
}

obter_analise_por_arquivo() {
    local nome="$1"
    local nome_esc
    nome_esc=$(escapar_sql "$nome")
    executar_sqlite_json \
        "SELECT * FROM analises WHERE nome_arquivo LIKE '%$nome_esc%' ORDER BY id DESC LIMIT 50;" \
        2>/dev/null || echo "[]"
}

obter_ultima_analise() {
    executar_sqlite_json \
        "SELECT * FROM analises ORDER BY id DESC LIMIT 1;" \
        2>/dev/null | jq '.[0] // null' 2>/dev/null || echo "null"
}

obter_estatisticas() {
    local total total_negocio total_ignorados framework configuracao biblioteca
    total=$(executar_sqlite "SELECT count(*) FROM analises;" 2>/dev/null || echo 0)
    total_negocio=$(executar_sqlite "SELECT count(*) FROM analises WHERE ignorado=0;" 2>/dev/null || echo 0)
    total_ignorados=$(executar_sqlite "SELECT count(*) FROM analises WHERE ignorado=1;" 2>/dev/null || echo 0)
    framework=$(executar_sqlite "SELECT count(*) FROM analises WHERE motivo='framework';" 2>/dev/null || echo 0)
    configuracao=$(executar_sqlite "SELECT count(*) FROM analises WHERE motivo='configuracao';" 2>/dev/null || echo 0)
    biblioteca=$(executar_sqlite "SELECT count(*) FROM analises WHERE motivo='biblioteca';" 2>/dev/null || echo 0)

    jq -n \
        --argjson total "$total" \
        --argjson negocio "$total_negocio" \
        --argjson ignorados "$total_ignorados" \
        --argjson framework "$framework" \
        --argjson configuracao "$configuracao" \
        --argjson biblioteca "$biblioteca" \
        '{total: $total, negocio: $negocio, ignorados: $ignorados, por_motivo: {framework: $framework, configuracao: $configuracao, biblioteca: $biblioteca}}'
}

salvar_ignorado() {
    local nome_arquivo="$1"
    local motivo="$2"
    local projeto_id="${3:-}"
    local user_id="${4:-0}"
    local data_hora
    data_hora=$(date '+%Y-%m-%d %H:%M:%S')
    local nome_esc interp_esc

    nome_esc=$(escapar_sql "$nome_arquivo")
    interp_esc=$(escapar_sql "Arquivo ignorado: $motivo")

    local projeto_clause
    if [ -n "$projeto_id" ] && [ "$projeto_id" != "null" ]; then
        projeto_clause="$projeto_id"
    else
        projeto_clause="NULL"
    fi

    executar_sqlite \
        "INSERT INTO analises (nome_arquivo, conteudo_arquivo, interpretacao, data_hora, hash_arquivo, ignorado, motivo, projeto_id, user_id)
         VALUES ('$nome_esc', '', '$interp_esc', '$data_hora', '', 1, '$motivo', $projeto_clause, $user_id);"
}

criar_projeto() {
    local nome="$1"
    local descricao="${2:-}"
    local user_id="${3:-0}"
    local data_hora
    data_hora=$(date '+%Y-%m-%d %H:%M:%S')
    local nome_esc desc_esc
    nome_esc=$(escapar_sql "$nome")
    desc_esc=$(escapar_sql "$descricao")

    executar_sqlite \
        "INSERT INTO projetos (nome, descricao, data_criacao, data_atualizacao, user_id)
         VALUES ('$nome_esc', '$desc_esc', '$data_hora', '$data_hora', $user_id);
         SELECT last_insert_rowid();"
}

listar_projetos() {
    local user_id="${1:-0}"
    local resultado
    resultado=$(executar_sqlite_json \
        "SELECT p.*,
            (SELECT COUNT(*) FROM projetos_arquivos WHERE projeto_id = p.id) as total_arquivos_real,
            (SELECT COUNT(*) FROM projetos_arquivos WHERE projeto_id = p.id AND status = 'analisado') as arquivos_analisados_real
         FROM projetos p
         WHERE p.user_id = $user_id
         ORDER BY p.id DESC;" 2>/dev/null)
    
    if [ -z "$resultado" ]; then
        echo "[]"
    else
        echo "$resultado"
    fi
}

obter_projeto_por_id_user() {
    local id="$1"
    local user_id="${2:-0}"
    executar_sqlite_json \
        "SELECT * FROM projetos WHERE id=$id AND user_id=$user_id;" \
        2>/dev/null | jq '.[0] // null' 2>/dev/null || echo "null"
}

obter_projeto_por_id() {
    local id="$1"
    executar_sqlite_json \
        "SELECT * FROM projetos WHERE id=$id;" \
        2>/dev/null | jq '.[0] // null' 2>/dev/null || echo "null"
}

obter_projeto_user_id() {
    local id="$1"
    executar_sqlite_json \
        "SELECT user_id FROM projetos WHERE id=$id;" \
        2>/dev/null | jq -r '.[0].user_id // "0"' 2>/dev/null || echo "0"
}

atualizar_projeto() {
    local id="$1"
    local campo="$2"
    local valor="$3"
    local valor_esc
    valor_esc=$(escapar_sql "$valor")
    local data_hora
    data_hora=$(date '+%Y-%m-%d %H:%M:%S')

    executar_sqlite \
        "UPDATE projetos SET $campo='$valor_esc', data_atualizacao='$data_hora' WHERE id=$id;"
}

atualizar_projeto_status() {
    local id="$1"
    local status="$2"
    local data_hora
    data_hora=$(date '+%Y-%m-%d %H:%M:%S')

    executar_sqlite \
        "UPDATE projetos SET status='$status', data_atualizacao='$data_hora' WHERE id=$id;"
}

excluir_projeto() {
    local id="$1"
    executar_sqlite "DELETE FROM analises_globais WHERE projeto_id=$id;"
    executar_sqlite "DELETE FROM projetos_arquivos WHERE projeto_id=$id;"
    executar_sqlite "DELETE FROM analises WHERE projeto_id=$id;"
    executar_sqlite "DELETE FROM projetos WHERE id=$id;"
    limpar_cache_antigo
}

limpar_cache_antigo() {
    executar_sqlite "DELETE FROM analises WHERE projeto_id IS NULL OR projeto_id NOT IN (SELECT id FROM projetos);" 2>/dev/null || true
    executar_sqlite "DELETE FROM analises_globais WHERE projeto_id != 0 AND projeto_id NOT IN (SELECT id FROM projetos);" 2>/dev/null || true
}

adicionar_arquivo_projeto() {
    local projeto_id="$1"
    local nome="$2"
    local caminho_relativo="$3"
    local tamanho="${4:-0}"
    local nome_esc caminho_esc
    nome_esc=$(escapar_sql "$nome")
    caminho_esc=$(escapar_sql "$caminho_relativo")

    executar_sqlite \
        "INSERT INTO projetos_arquivos (projeto_id, nome, caminho_relativo, tamanho)
         VALUES ($projeto_id, '$nome_esc', '$caminho_esc', $tamanho);"

    obter_ultimo_id >/dev/null
}

listar_arquivos_projeto() {
    local projeto_id="$1"
    local resultado
    resultado=$(executar_sqlite_json \
        "SELECT * FROM projetos_arquivos WHERE projeto_id=$projeto_id ORDER BY caminho_relativo;" \
        2>/dev/null)
    if [ -z "$resultado" ]; then
        echo "[]"
    else
        echo "$resultado"
    fi
}

atualizar_arquivo_projeto_status() {
    local arquivo_id="$1"
    local status="$2"
    local analise_id="${3:-}"

    if [ -n "$analise_id" ] && [ "$analise_id" != "null" ]; then
        executar_sqlite \
            "UPDATE projetos_arquivos SET status='$status', analise_id=$analise_id WHERE id=$arquivo_id;"
    else
        executar_sqlite \
            "UPDATE projetos_arquivos SET status='$status' WHERE id=$arquivo_id;"
    fi
}

obter_analises_projeto() {
    local projeto_id="$1"
    local resultado
    resultado=$(executar_sqlite_json \
        "SELECT id, nome_arquivo, interpretacao, data_hora, hash_arquivo, ignorado, motivo, projeto_id
         FROM analises WHERE projeto_id=$projeto_id ORDER BY id DESC;" \
        2>/dev/null)
    if [ -z "$resultado" ]; then
        echo "[]"
    else
        echo "$resultado"
    fi
}

incrementar_arquivos_analisados() {
    local projeto_id="$1"
    executar_sqlite \
        "UPDATE projetos SET arquivos_analisados = arquivos_analisados + 1 WHERE id=$projeto_id;"
}

obter_estatisticas_projeto() {
    local projeto_id="$1"
    local total analisados pendentes erros

    total=$(executar_sqlite "SELECT COUNT(*) FROM projetos_arquivos WHERE projeto_id=$projeto_id;" 2>/dev/null || echo 0)
    analisados=$(executar_sqlite "SELECT COUNT(*) FROM projetos_arquivos WHERE projeto_id=$projeto_id AND status='analisado';" 2>/dev/null || echo 0)
    pendentes=$(executar_sqlite "SELECT COUNT(*) FROM projetos_arquivos WHERE projeto_id=$projeto_id AND status='pendente';" 2>/dev/null || echo 0)
    erros=$(executar_sqlite "SELECT COUNT(*) FROM projetos_arquivos WHERE projeto_id=$projeto_id AND status='erro';" 2>/dev/null || echo 0)

    jq -n \
        --argjson total "$total" \
        --argjson analisados "$analisados" \
        --argjson pendentes "$pendentes" \
        --argjson erros "$erros" \
        '{total: $total, analisados: $analisados, pendentes: $pendentes, erros: $erros}'
}

salvar_analise_global() {
    local projeto_id="$1"
    local interpretacao="$2"
    local arvore="$3"
    local user_id="${4:-0}"
    local data_hora interpretacao_esc arvore_esc
    data_hora=$(date '+%Y-%m-%d %H:%M:%S')
    interpretacao_esc=$(escapar_sql "$interpretacao")
    arvore_esc=$(escapar_sql "$arvore")

    local projeto_clause
    if [ -n "$projeto_id" ] && [ "$projeto_id" != "null" ]; then
        projeto_clause="$projeto_id"
    else
        projeto_clause="0"
    fi

    executar_sqlite \
        "INSERT INTO analises_globais (projeto_id, interpretacao, arvore_arquivos, data_hora, user_id)
         VALUES ($projeto_clause, '$interpretacao_esc', '$arvore_esc', '$data_hora', $user_id);"
}

obter_ultimo_id_global() {
    executar_sqlite "SELECT last_insert_rowid() FROM analises_globais LIMIT 1;" 2>/dev/null || echo 0
}

obter_analise_global_projeto() {
    local projeto_id="$1"
    executar_sqlite_json \
        "SELECT * FROM analises_globais WHERE projeto_id=$projeto_id ORDER BY id DESC LIMIT 1;" \
        2>/dev/null | jq '.[0] // null' 2>/dev/null || echo "null"
}
