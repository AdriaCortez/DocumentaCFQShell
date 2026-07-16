#!/usr/bin/env bash
set -euo pipefail

# ─── Lógica de retentativa com backoff ───

executar_com_retry() {
    local funcao="$1"; shift
    local descricao="${1:-operação}"; shift || true

    local tentativa=1
    local ultimo_erro=""

    while [ $tentativa -le "$MAXIMO_RETENTATIVAS" ]; do
        local saida
        if saida=$("$funcao" "$@" 2>/tmp/retry_erro_$$); then
            rm -f "/tmp/retry_erro_$$"
            printf '%s' "$saida"
            return 0
        fi

        ultimo_erro=$(cat /tmp/retry_erro_$$ 2>/dev/null || true)
        rm -f "/tmp/retry_erro_$$"

        if [ $tentativa -eq "$MAXIMO_RETENTATIVAS" ]; then
            printf '✗ %s falhou após %d tentativa(s): %s\n' "$descricao" "$MAXIMO_RETENTATIVAS" "$ultimo_erro" >&2
            return 1
        fi

        printf '⚠ Tentativa %d/%d de %s falhou (%s). Aguardando %ds...\n' \
            "$tentativa" "$MAXIMO_RETENTATIVAS" "$descricao" "$ultimo_erro" "$INTERVALO_RETENTATIVA" >&2
        sleep "$INTERVALO_RETENTATIVA"
        ((tentativa++))
    done

    return 1
}

analisar_com_retry() {
    local prompt_sistema="$1"
    local prompt_usuario="$2"
    local nome_arquivo="$3"

    local tentativa=1
    local interpretacao=""
    local ultimo_erro=""

    while [ $tentativa -le "$MAXIMO_RETENTATIVAS" ]; do
        local saida_arquivo erro_arquivo
        saida_arquivo=$(mktemp)
        erro_arquivo=$(mktemp)

        chamar_ollama "$prompt_sistema" "$prompt_usuario" "$saida_arquivo" "$erro_arquivo"
        local codigo=$?

        if [ $codigo -eq 0 ]; then
            interpretacao=$(cat "$saida_arquivo")
            rm -f "$saida_arquivo" "$erro_arquivo"
            printf '%s' "$interpretacao"
            return 0
        fi

        ultimo_erro=$(obter_erro_ollama "$erro_arquivo")
        [ -z "$ultimo_erro" ] && ultimo_erro="codigo de saida: $codigo (Ollama indisponivel ou resposta vazia)"
        rm -f "$saida_arquivo" "$erro_arquivo"

        if [ $tentativa -eq "$MAXIMO_RETENTATIVAS" ]; then
            printf '✗ [%s] Falhou após %d tentativas: %s\n' "$nome_arquivo" "$MAXIMO_RETENTATIVAS" "$ultimo_erro" >&2
            return 1
        fi

        printf '⚠ [%s] Tentativa %d/%d falhou (%s). Aguardando %ds...\n' \
            "$nome_arquivo" "$tentativa" "$MAXIMO_RETENTATIVAS" "$ultimo_erro" "$INTERVALO_RETENTATIVA" >&2
        sleep "$INTERVALO_RETENTATIVA"
        ((tentativa++))
    done

    return 1
}
