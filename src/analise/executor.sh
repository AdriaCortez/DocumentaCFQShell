#!/usr/bin/env bash
set -euo pipefail

# ─── Executor de análise por arquivo ───

executar_analise_arquivo() {
    local caminho="$1"
    local hash_arquivo="$2"
    local prompt_sistema="$3"
    local prompt_usuario="$4"
    local indice="${5:-0}"
    local total="${6:-1}"

    exibir_progresso "$indice" "$total" "$caminho"

    local interpretacao
    if interpretacao=$(analisar_com_retry "$prompt_sistema" "$prompt_usuario" "$caminho" 2>/tmp/executor_erro_$$); then
        local conteudo
        conteudo=$(cat "$caminho" 2>/dev/null || echo "")

        salvar_analise "$caminho" "$conteudo" "$interpretacao" "$hash_arquivo" 0 "negocio"

        local ultimo_id
        ultimo_id=$(obter_ultimo_id)

        printf '%s' "$interpretacao"

        local resultado
        resultado=$(jq -n \
            --arg status "sucesso" \
            --argjson id "$ultimo_id" \
            --arg interpretacao "$interpretacao" \
            '{status: $status, id: $id, interpretacao: $interpretacao}')

        printf '%s' "$resultado"
        return 0
    else
        local erro_msg
        erro_msg=$(cat /tmp/executor_erro_$$ 2>/dev/null || echo "Erro desconhecido")
        rm -f /tmp/executor_erro_$$

        exibir_erro "Falha ao analisar: $caminho — $erro_msg"

        local resultado
        resultado=$(jq -n \
            --arg status "erro" \
            --arg mensagem "$erro_msg" \
            '{status: $status, erro: $mensagem}')

        printf '%s' "$resultado"
        return 1
    fi
}

executar_analise_arquivo_via_api() {
    local dados_json="$1"

    local prompt_sistema prompt_usuario template_tipo
    prompt_sistema=$(printf '%s' "$dados_json" | jq -r '.prompt_sistema // ""')
    prompt_usuario=$(printf '%s' "$dados_json" | jq -r '.prompt_usuario // ""')
    template_tipo=$(printf '%s' "$dados_json" | jq -r '.template // "padrao"')

    if [ -n "$prompt_sistema" ] && [ -n "$prompt_usuario" ]; then
        true
    else
        local metadados arquivo analises_concluidas
        metadados=$(printf '%s' "$dados_json" | jq -r '.metadados // {}')
        arquivo=$(printf '%s' "$dados_json" | jq -r '.arquivo // {}')
        analises_concluidas=$(printf '%s' "$dados_json" | jq -r '.analises_concluidas // []')

        local prompt_completo
        prompt_completo=$(construir_prompt_completo "$template_tipo" "$metadados" "$arquivo" "$analises_concluidas")

        prompt_sistema=$(printf '%s' "$prompt_completo" | jq -r '.sistema // ""')
        prompt_usuario=$(printf '%s' "$prompt_completo" | jq -r '.usuario // ""')
    fi

    local nome_arquivo caminho hash_arquivo conteudo
    nome_arquivo=$(printf '%s' "$dados_json" | jq -r '.arquivo.caminho // "arquivo_desconhecido"')
    caminho="$nome_arquivo"
    hash_arquivo=$(printf '%s' "$dados_json" | jq -r '.hash_arquivo // ""')
    conteudo=$(printf '%s' "$dados_json" | jq -r '.arquivo.conteudo // ""')

    if [ -z "$hash_arquivo" ] && [ -n "$conteudo" ]; then
        hash_arquivo=$(calcular_hash_texto "$conteudo")
    fi

    if [ -n "$hash_arquivo" ] && verificar_hash_existe "$hash_arquivo"; then
        local cache
        cache=$(obter_analise_por_hash "$hash_arquivo")

        local cache_id cache_interpretacao
        cache_id=$(printf '%s' "$cache" | jq -r '.id // 0')
        cache_interpretacao=$(printf '%s' "$cache" | jq -r '.interpretacao // ""')

        local resultado_cache
        resultado_cache=$(jq -n \
            --arg status "cacheado" \
            --argjson id "$cache_id" \
            --arg interpretacao "$cache_interpretacao" \
            --argjson cacheado true \
            '{status: $status, id: $id, interpretacao: $interpretacao, cacheado: $cacheado}')

        printf '%s' "$resultado_cache"
        return 0
    fi

    local interpretacao
    if interpretacao=$(analisar_com_retry "$prompt_sistema" "$prompt_usuario" "$nome_arquivo" 2>/tmp/executor_api_erro_$$); then
        salvar_analise "$nome_arquivo" "$conteudo" "$interpretacao" "$hash_arquivo" 0 "negocio"

        local ultimo_id
        ultimo_id=$(obter_ultimo_id)

        local resultado
        resultado=$(jq -n \
            --arg status "concluido" \
            --argjson id "$ultimo_id" \
            --arg interpretacao "$interpretacao" \
            --argjson cacheado false \
            '{status: $status, id: $id, resposta_bruta: $interpretacao, cacheado: $cacheado}')

        printf '%s' "$resultado"
        return 0
    else
        local erro_msg
        erro_msg=$(cat /tmp/executor_api_erro_$$ 2>/dev/null || echo "Erro desconhecido")
        rm -f /tmp/executor_api_erro_$$

        local resultado
        resultado=$(jq -n \
            --arg status "erro" \
            --arg mensagem "$erro_msg" \
            '{status: $status, erro: $mensagem}')

        printf '%s' "$resultado"
        return 1
    fi
}
