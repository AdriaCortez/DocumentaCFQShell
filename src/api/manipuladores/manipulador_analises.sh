#!/usr/bin/env bash
set -euo pipefail

# ─── Manipuladores de análises ───

tratar_listar_analises() {
    local resultado
    resultado=$(obter_analises)
    enviar_json 200 "$resultado"
}

tratar_analise_por_id() {
    local id="$1"
    local resultado
    resultado=$(obter_analise_por_id "$id")

    if [ "$resultado" = "null" ]; then
        enviar_erro 404 "Análise não encontrada"
    else
        enviar_json 200 "$resultado"
    fi
}

tratar_analise_por_arquivo() {
    local nome="$1"
    local resultado
    resultado=$(obter_analise_por_arquivo "$nome")
    enviar_json 200 "$resultado"
}

tratar_ultima_analise() {
    local resultado
    resultado=$(obter_ultima_analise)
    enviar_json 200 "$resultado"
}

tratar_estatisticas() {
    local resultado
    resultado=$(obter_estatisticas)
    enviar_json 200 "$resultado"
}
