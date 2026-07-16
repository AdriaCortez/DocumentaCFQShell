#!/usr/bin/env bash
set -euo pipefail

# ─── Gestão da fila de arquivos ───

definir_fila() {
    printf '%s\n' "$@" > "$ARQUIVO_FILA"
}

obter_fila() {
    if [ -f "$ARQUIVO_FILA" ]; then
        cat "$ARQUIVO_FILA"
    fi
}

obter_fila_json() {
    local arquivos
    if [ -f "$ARQUIVO_FILA" ]; then
        arquivos=$(jq -R -s 'split("\n") | map(select(length > 0))' "$ARQUIVO_FILA")
    else
        arquivos="[]"
    fi

    local status_raw
    status_raw=$(obter_status)
    local status="${status_raw%%|*}"

    jq -n \
        --argjson arquivos "$arquivos" \
        --arg status "$status" \
        '{status: $status, arquivos: $arquivos}'
}

total_na_fila() {
    if [ -f "$ARQUIVO_FILA" ]; then
        wc -l < "$ARQUIVO_FILA"
    else
        echo 0
    fi
}
