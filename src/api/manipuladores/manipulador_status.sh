#!/usr/bin/env bash
set -euo pipefail

# ─── Manipulador: GET /api/v1/status ───

tratar_status() {
    local status_raw status pid pid_valido
    status_raw=$(obter_status)
    IFS='|' read -r status pid pid_valido <<< "$status_raw"

    local json_progresso
    json_progresso=$(obter_json_progresso)

    local resposta
    resposta=$(jq -n \
        --arg status "$status" \
        --arg pid "$pid" \
        --arg pid_valido "$pid_valido" \
        --argjson progresso "$json_progresso" \
        '{
            status: $status,
            pid: $pid,
            pid_valido: $pid_valido,
            progresso: $progresso
        }')

    enviar_json 200 "$resposta"
}
