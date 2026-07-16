#!/usr/bin/env bash
set -euo pipefail

# ─── Manipulador: GET /api/v1/progresso ───

tratar_progresso() {
    local json_progresso
    json_progresso=$(obter_json_progresso)

    enviar_json 200 "$json_progresso"
}
