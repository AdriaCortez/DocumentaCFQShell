#!/usr/bin/env bash
set -euo pipefail

# ─── Manipulador: POST /api/v1/analisar ───
# Inicia análise em lote num diretório

tratar_iniciar() {
    limpar_processos_travados

    local status_raw status pid pid_valido
    status_raw=$(obter_status)
    IFS='|' read -r status pid pid_valido <<< "$status_raw"

    if [ "$status" = "executando" ]; then
        if [ "$pid_valido" = "true" ] && [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            local resposta
            resposta=$(jq -n \
                --arg status "ja_em_execucao" \
                --arg mensagem "Já existe uma análise em execução" \
                --arg pid "$pid" \
                '{status: $status, mensagem: $mensagem, pid: $pid}')
            enviar_json 409 "$resposta"
            return
        else
            definir_status "parado"
        fi
    fi

    local diretorio="."
    if [ -n "$CORPO" ] && [ "${CABECALHOS[content-type]:-}" = "application/json" ]; then
        diretorio=$(printf '%s' "$CORPO" | jq -r '.diretorio // "."' 2>/dev/null || echo ".")
    fi

    if [ ! -d "$diretorio" ]; then
        local resposta
        resposta=$(jq -n --arg msg "Diretório não encontrado: $diretorio" --argjson codigo 400 \
            '{erro: $msg, codigo: $codigo}')
        enviar_json 400 "$resposta"
        return
    fi

    inicializar_controle
    inicializar_eventos
    definir_status "executando"

    local diretorio_scripts
    diretorio_scripts="$DIRETORIO_RAIZ"

    setsid bash "$diretorio_scripts/src/analise/analisar.sh" "$diretorio" \
        >> "$ARQUIVO_LOG" 2>&1 </dev/null &
    local pid_novo=$!
    disown
    definir_pid "$pid_novo"

    local resposta
    resposta=$(jq -n \
        --arg status "iniciado" \
        --arg mensagem "Análise iniciada em background" \
        --argjson pid "$pid_novo" \
        --arg diretorio "$diretorio" \
        '{status: $status, mensagem: $mensagem, pid: $pid, diretorio: $diretorio}')

    enviar_json 200 "$resposta"
}
