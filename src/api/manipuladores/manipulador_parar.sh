#!/usr/bin/env bash
set -euo pipefail

# ─── Manipulador: POST /api/v1/analisar/parar ───

tratar_parar() {
    local status_raw status pid pid_valido
    status_raw=$(obter_status)
    IFS='|' read -r status pid pid_valido <<< "$status_raw"

    if [ "$status" != "executando" ]; then
        local resposta
        resposta=$(jq -n \
            --arg status "sem_analise" \
            --arg mensagem "Nenhuma análise em execução" \
            '{status: $status, mensagem: $mensagem}')
        enviar_json 200 "$resposta"
        return
    fi

    definir_status "parando"

    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
        kill -TERM "$pid" 2>/dev/null || true
    fi

    escrever_evento "parada_solicitada" "$(jq -n --arg pid "$pid" '{pid: $pid}')"

    local resposta
    resposta=$(jq -n \
        --arg status "parando" \
        --arg mensagem "Solicitação de parada enviada" \
        '{status: $status, mensagem: $mensagem}')

    enviar_json 200 "$resposta"
}
