#!/usr/bin/env bash
set -euo pipefail

# ─── Gestão de progresso da análise ───

obter_progresso() {
    if [ -f "$ARQUIVO_PROGRESSO" ]; then
        cat "$ARQUIVO_PROGRESSO"
    else
        echo "0/0|"
    fi
}

definir_progresso() {
    local atual="$1"
    local total="$2"
    local arquivo="$3"
    printf '%s/%s|%s' "$atual" "$total" "$arquivo" > "$ARQUIVO_PROGRESSO"
}

calcular_percentual() {
    local atual="$1"
    local total="$2"
    if [ "${total:-0}" -gt 0 ] 2>/dev/null; then
        echo $(( (atual * 100) / total ))
    else
        echo 0
    fi
}

obter_json_progresso() {
    local raw atual total arquivo_atual percentual
    raw=$(obter_progresso)
    atual="${raw%%/*}"
    total="${raw#*/}"; total="${total%%|*}"
    arquivo_atual="${raw#*|}"

    percentual=$(calcular_percentual "${atual:-0}" "${total:-0}")

    jq -n \
        --argjson atual "${atual:-0}" \
        --argjson total "${total:-0}" \
        --argjson percentual "$percentual" \
        --arg arquivo_atual "$arquivo_atual" \
        '{atual: $atual, total: $total, percentual: $percentual, arquivo_atual: $arquivo_atual}'
}
