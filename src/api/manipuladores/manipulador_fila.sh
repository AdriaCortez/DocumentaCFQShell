#!/usr/bin/env bash
set -euo pipefail

# ─── Manipulador: GET /api/v1/fila ───

tratar_fila() {
    local resultado
    resultado=$(obter_fila_json)
    enviar_json 200 "$resultado"
}
