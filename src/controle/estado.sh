#!/usr/bin/env bash
set -euo pipefail

# ─── Gestão de estado da análise ───

inicializar_controle() {
    mkdir -p "$DIRETORIO_CONTROLE"
}

obter_status() {
    if [ -f "$ARQUIVO_STATUS" ]; then
        local status_raw
        status_raw=$(cat "$ARQUIVO_STATUS")
        local pid=""
        if [ -f "$ARQUIVO_PID" ]; then
            pid=$(cat "$ARQUIVO_PID")
        fi
        local pid_valido="false"
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            pid_valido="true"
        fi
        echo "$status_raw|$pid|$pid_valido"
    else
        echo "parado||false"
    fi
}

definir_status() {
    local novo_status="$1"
    printf '%s' "$novo_status" > "$ARQUIVO_STATUS"
}

definir_pid() {
    local pid="$1"
    printf '%s' "$pid" > "$ARQUIVO_PID"
}

analise_em_execucao() {
    local status_raw pid pid_valido
    IFS='|' read -r status_raw pid pid_valido <<< "$(obter_status)"

    [ "$status_raw" = "executando" ] && [ "$pid_valido" = "true" ]
}

aguardar_parada() {
    local status_raw
    if [ -f "$ARQUIVO_STATUS" ]; then
        status_raw=$(cat "$ARQUIVO_STATUS")
        [ "$status_raw" = "parando" ]
    else
        return 1
    fi
}

limpar_controle() {
    rm -f "$ARQUIVO_STATUS" "$ARQUIVO_PID" "$ARQUIVO_PROGRESSO" "$ARQUIVO_FILA"
    rm -f "$DIRETORIO_CONTROLE"/*.tmp 2>/dev/null || true
}

limpar_processos_travados() {
    local status_raw pid pid_valido
    status_raw=$(obter_status)
    IFS='|' read -r status_raw pid pid_valido <<< "$status_raw"

    if [ "$status_raw" = "executando" ] && [ "$pid_valido" = "false" ]; then
        local projeto_id
        projeto_id=$(cat "$ARQUIVO_PROJETO_ATUAL" 2>/dev/null || echo "")
        if [ -n "$projeto_id" ] && [ -f "$ARQUIVO_BANCO" ]; then
            executar_sqlite "UPDATE projetos_arquivos SET status='pendente' WHERE status='analisando' AND projeto_id=$projeto_id;" 2>/dev/null || true
            executar_sqlite "UPDATE projetos SET status='pronto' WHERE id=$projeto_id AND status='processando';" 2>/dev/null || true
        fi
        limpar_controle
        definir_status "parado"
    fi

    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
        local stat
        stat=$(ps -p "$pid" -o stat= 2>/dev/null || echo "")
        if printf '%s' "$stat" | grep -q "Z"; then
            kill -9 "$pid" 2>/dev/null || true
            local projeto_id
            projeto_id=$(cat "$ARQUIVO_PROJETO_ATUAL" 2>/dev/null || echo "")
            if [ -n "$projeto_id" ] && [ -f "$ARQUIVO_BANCO" ]; then
                executar_sqlite "UPDATE projetos_arquivos SET status='pendente' WHERE status='analisando' AND projeto_id=$projeto_id;" 2>/dev/null || true
                executar_sqlite "UPDATE projetos SET status='pronto' WHERE id=$projeto_id AND status='processando';" 2>/dev/null || true
            fi
            limpar_controle
            definir_status "parado"
        fi
    fi
}
