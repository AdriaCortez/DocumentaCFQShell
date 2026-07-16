#!/usr/bin/env bash
set -euo pipefail

# ─── Manipulador: GET /api/v1/stream (SSE) ───

tratar_stream() {
    local extras=""
    extras+="Cache-Control: no-cache\r\n"
    extras+="Connection: keep-alive\r\n"
    extras+="X-Accel-Buffering: no"

    printf "HTTP/1.1 200 OK\r\n"
    printf "Content-Type: text/event-stream\r\n"
    printf "%s\r\n\r\n" "$extras"

    touch "$ARQUIVO_EVENTOS" 2>/dev/null || true

    printf "event: conectado\ndata: {\"mensagem\":\"Stream iniciado\"}\n\n"
    printf ": keepalive\n\n"

    tail -f "$ARQUIVO_EVENTOS" 2>/dev/null | while IFS= read -r linha; do
        [ -z "$linha" ] && continue
        if ! printf "" 2>/dev/null; then
            break
        fi
        local nome_evento
        nome_evento=$(printf '%s' "$linha" | jq -r '.evento // "mensagem"' 2>/dev/null || echo "mensagem")
        printf "event: %s\ndata: %s\n\n" "$nome_evento" "$linha"
    done
}
