#!/usr/bin/env bash
set -euo pipefail

# ─── Funções de validação e sanitização ───

escapar_sql() {
    printf '%s' "$1" | sed "s/'/''/g"
}

calcular_hash() {
    local caminho="$1"
    sha256sum "$caminho" 2>/dev/null | awk '{print $1}'
}

calcular_hash_texto() {
    local conteudo="$1"
    printf '%s' "$conteudo" | sha256sum | awk '{print $1}'
}

validar_dependencias() {
    local faltantes=()
    for cmd in curl jq find sqlite3; do
        if ! command -v "$cmd" &>/dev/null; then
            faltantes+=("$cmd")
        fi
    done

    if [ ${#faltantes[@]} -gt 0 ]; then
        printf 'Erro: dependências faltando: %s\n' "${faltantes[*]}" >&2
        return 1
    fi
    return 0
}

validar_diretorio() {
    local caminho="$1"
    if [ ! -d "$caminho" ]; then
        printf 'Erro: diretório não encontrado: %s\n' "$caminho" >&2
        return 1
    fi
    return 0
}

validar_arquivo() {
    local caminho="$1"
    if [ ! -f "$caminho" ] || [ ! -r "$caminho" ]; then
        printf 'Erro: arquivo não encontrado ou sem permissão de leitura: %s\n' "$caminho" >&2
        return 1
    fi
    return 0
}

validar_json() {
    local json="$1"
    if ! printf '%s' "$json" | jq empty 2>/dev/null; then
        return 1
    fi
    return 0
}

verificar_ollama() {
    local url_base="${URL_OLLAMA%/*}"

    if ! curl -sf --max-time 5 "$url_base/tags" >/dev/null 2>&1; then
        exibir_erro "Ollama nao esta acessivel em $url_base"
        return 1
    fi

    if ! curl -sf --max-time 5 "$url_base/tags" | jq -e ".models[] | select(.name | contains(\"$MODELO\"))" >/dev/null 2>&1; then
        exibir_erro "Modelo $MODELO nao encontrado no Ollama"
        return 1
    fi

    exibir_info "Ollama OK — modelo $MODELO disponivel"
    return 0
}

validar_resposta_http() {
    local resposta="$1"
    if [ -z "$resposta" ]; then
        return 1
    fi
    local http_status
    http_status=$(printf '%s' "$resposta" | jq -r '.error // empty' 2>/dev/null)
    if [ -n "$http_status" ]; then
        return 1
    fi
    return 0
}

codificar_json() {
    jq -R -s '.' <<< "$1" 2>/dev/null || printf '"%s"' "$1"
}
