#!/usr/bin/env bash
set -euo pipefail

# ─── Funções de log ───
# Usa MODO_SILENCIOSO para suprimir saída visual em modo serviço

exibir_log() {
    if [ "${MODO_SILENCIOSO:-false}" != "true" ]; then
        printf '%s\n' "$1"
    fi
}

exibir_info() {
    local mensagem="$1"
    if [ "${MODO_SILENCIOSO:-false}" != "true" ]; then
        printf '[INFO] %s\n' "$mensagem"
    fi
}

exibir_progresso() {
    local indice="$1"
    local total="$2"
    local arquivo="$3"
    if [ "${MODO_SILENCIOSO:-false}" != "true" ]; then
        printf '[%d/%d] Analisando: %s\n' "$((indice + 1))" "$total" "$arquivo"
    fi
}

exibir_sucesso() {
    local mensagem="$1"
    if [ "${MODO_SILENCIOSO:-false}" != "true" ]; then
        printf '✓ %s\n' "$mensagem"
    fi
}

exibir_erro() {
    local mensagem="$1"
    printf '✗ %s\n' "$mensagem" >&2
}

exibir_aviso() {
    local mensagem="$1"
    if [ "${MODO_SILENCIOSO:-false}" != "true" ]; then
        printf '⚠ %s\n' "$mensagem"
    fi
}

exibir_cache() {
    local arquivo="$1"
    if [ "${MODO_SILENCIOSO:-false}" != "true" ]; then
        printf '⊘ Cache: %s\n' "$arquivo"
    fi
}

escrever_log_arquivo() {
    local nivel="$1"
    local mensagem="$2"
    local data_hora
    data_hora=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$data_hora] [$nivel] $mensagem" >> "$ARQUIVO_LOG"
}

separador_visual() {
    if [ "${MODO_SILENCIOSO:-false}" != "true" ]; then
        printf '─%.0s' $(seq 1 55)
        printf '\n'
    fi
}
