#!/usr/bin/env bash
set -euo pipefail

# ─── Cliente Ollama com streaming ───

chamar_ollama() {
    local prompt_sistema="$1"
    local prompt_usuario="$2"
    local saida_arquivo="$3"
    local arquivo_erro="$4"

    > "$saida_arquivo"
    > "$arquivo_erro"

    local payload
    payload=$(jq -n \
        --arg model "$MODELO" \
        --argjson sistema "$(printf '%s' "$prompt_sistema" | jq -R -s '.')" \
        --argjson usuario "$(printf '%s' "$prompt_usuario" | jq -R -s '.')" \
        '{
            model: $model,
            messages: [
                {role: "system", content: $sistema},
                {role: "user", content: $usuario}
            ],
            stream: true,
            options: {
                temperature: ('"$TEMPERATURA_LLM"'),
                num_ctx: ('"$TAMANHO_CONTEXTO"')
            }
        }')

    set +o pipefail
    curl -s -f --no-buffer \
        --max-time "$TIMEOUT_REQUISICAO" \
        -X POST "$URL_OLLAMA" \
        -H 'Content-Type: application/json' \
        -d "$payload" 2>"$arquivo_erro" | \
    while IFS= read -r linha; do
        [ -z "$linha" ] && continue
        printf '%s' "$linha" | jq -j 'select(.message.content != null and .done != true) | .message.content' 2>/dev/null >> "$saida_arquivo" || true
    done
    local codigo_saida=${PIPESTATUS[0]}
    set -o pipefail

    if [ ! -s "$saida_arquivo" ]; then
        printf 'Resposta vazia da LLM\n' >"$arquivo_erro"
        return 1
    fi

    if grep -q '"error"' "$arquivo_erro" 2>/dev/null; then
        return 1
    fi

    return $codigo_saida
}

chamar_ollama_sem_stream() {
    local prompt_sistema="$1"
    local prompt_usuario="$2"

    local payload
    payload=$(jq -n \
        --arg model "$MODELO" \
        --argjson sistema "$(printf '%s' "$prompt_sistema" | jq -R -s '.')" \
        --argjson usuario "$(printf '%s' "$prompt_usuario" | jq -R -s '.')" \
        '{
            model: $model,
            messages: [
                {role: "system", content: $sistema},
                {role: "user", content: $usuario}
            ],
            stream: false,
            options: {
                temperature: ('"$TEMPERATURA_LLM"'),
                num_ctx: ('"$TAMANHO_CONTEXTO"')
            }
        }')

    local resposta
    resposta=$(curl -s -f \
        --max-time "$TIMEOUT_REQUISICAO" \
        -X POST "$URL_OLLAMA" \
        -H 'Content-Type: application/json' \
        -d "$payload" 2>/dev/null)

    printf '%s' "$resposta" | jq -r '.message.content // empty' 2>/dev/null
}

chamar_ollama_legado() {
    local nome_arquivo="$1"
    local conteudo="$2"
    local prompt_personalizado="${3:-}"

    local prompt
    if [ -n "$prompt_personalizado" ]; then
        prompt="$prompt_personalizado"
    else
        prompt=$(printf 'Analise o arquivo %s e explique:\n1. O que o código faz (contexto e propósito)\n2. Variáveis utilizadas\n3. Bugs ou problemas de sintaxe\n4. Sugestões de melhoria\n\nCódigo:\n%s' "$nome_arquivo" "$conteudo")
    fi

    local payload
    payload=$(jq -n \
        --arg model "$MODELO" \
        --arg prompt "$prompt" \
        '{model: $model, prompt: $prompt, stream: true, options: {temperature: ('"$TEMPERATURA_LLM"'), num_ctx: ('"$TAMANHO_CONTEXTO"')}}')

    local saida_arquivo erro_arquivo
    saida_arquivo=$(mktemp)
    erro_arquivo=$(mktemp)

    set +o pipefail
    curl -s -f --no-buffer \
        --max-time "$TIMEOUT_REQUISICAO" \
        -X POST "$URL_OLLAMA_GENERATE" \
        -H 'Content-Type: application/json' \
        -d "$payload" 2>"$erro_arquivo" | \
    while IFS= read -r linha; do
        [ -z "$linha" ] && continue
        printf '%s' "$linha" | jq -j 'select(.response != null and .done != true) | .response' 2>/dev/null | tee -a "$saida_arquivo" || true
    done
    local codigo_saida=${PIPESTATUS[0]}
    set -o pipefail

    local resposta erro_msg
    resposta=$(cat "$saida_arquivo")
    erro_msg=$(head -c 200 "$erro_arquivo" 2>/dev/null || true)

    rm -f "$saida_arquivo" "$erro_arquivo"

    if [ $codigo_saida -ne 0 ]; then
        printf '%s' "$erro_msg" >&2
        return 1
    fi

    printf '%s' "$resposta"
    return 0
}

obter_erro_ollama() {
    local arquivo_erro="$1"
    head -c 200 "$arquivo_erro" 2>/dev/null || true
}
