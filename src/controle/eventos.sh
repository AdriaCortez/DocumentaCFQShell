#!/usr/bin/env bash
set -euo pipefail

# ─── Gestão de eventos SSE ───

inicializar_eventos() {
    :> "$ARQUIVO_EVENTOS"
}

escrever_evento() {
    local nome_evento="$1"
    local dados="$2"
    printf '{"evento":"%s","data":%s}\n' "$nome_evento" "$dados" >> "$ARQUIVO_EVENTOS"
}

escrever_evento_simples() {
    local nome_evento="$1"
    local dados_brutos="$2"
    printf '{"evento":"%s",%s}\n' "$nome_evento" "$dados_brutos" >> "$ARQUIVO_EVENTOS"
}

notificar_progresso_arquivo() {
    local indice="$1"
    local total="$2"
    local arquivo="$3"
    local status="$4"
    local extras="${5:-}"

    local payload
    payload=$(jq -n \
        --arg arquivo "$arquivo" \
        --argjson indice "$indice" \
        --argjson total "$total" \
        --arg status "$status" \
        --argjson extras "${extras:-{}}" \
        '{arquivo: $arquivo, indice: $indice, total: $total, status: $status} * $extras')

    escrever_evento "progresso_arquivo" "$payload"
}

notificar_finalizado() {
    local sucessos="$1"
    local erros="$2"
    local ignorados="$3"
    local mensagem="${4:-}"

    local payload
    payload=$(jq -n \
        --argjson sucessos "$sucessos" \
        --argjson erros "$erros" \
        --argjson ignorados "$ignorados" \
        --arg mensagem "$mensagem" \
        '{total_sucessos: $sucessos, total_erros: $erros, total_ignorados: $ignorados, mensagem: $mensagem}')

    escrever_evento "finalizado" "$payload"
}

notificar_erro() {
    local codigo="$1"
    local mensagem="$2"
    local detalhes="${3:-}"

    local payload
    payload=$(jq -n \
        --arg codigo "$codigo" \
        --arg mensagem "$mensagem" \
        --arg detalhes "$detalhes" \
        '{codigo: $codigo, mensagem: $mensagem, detalhes: $detalhes}')

    escrever_evento "erro" "$payload"
}

notificar_analise_global_iniciada() {
    local total_arquivos="$1"
    local payload
    payload=$(jq -n \
        --argjson total "$total_arquivos" \
        '{total_arquivos: $total}')
    escrever_evento "analise_global_iniciada" "$payload"
}

notificar_analise_global_concluida() {
    local id="$1"
    local payload
    payload=$(jq -n \
        --argjson id "$id" \
        '{id: $id}')
    escrever_evento "analise_global_concluida" "$payload"
}

notificar_analise_global_erro() {
    local erro="$1"
    local payload
    payload=$(jq -n \
        --arg erro "$erro" \
        '{erro: $erro}')
    escrever_evento "analise_global_erro" "$payload"
}
