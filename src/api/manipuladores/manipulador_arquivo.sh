#!/usr/bin/env bash
set -euo pipefail

# ─── Manipulador: POST /api/v1/analisar/arquivo ───
# Analisa um único arquivo com prompt customizado

tratar_analisar_arquivo() {
    if [ -z "$CORPO" ]; then
        enviar_erro 400 "Corpo da requisição vazio"
        return
    fi

    if ! validar_json "$CORPO"; then
        enviar_erro 400 "JSON inválido no corpo da requisição"
        return
    fi

    local metadados arquivo_dados template_tipo analises_concluidas hash_arquivo prompt_sistema prompt_usuario

    metadados=$(printf '%s' "$CORPO" | jq -c '.metadados // {}')
    arquivo_dados=$(printf '%s' "$CORPO" | jq -c '.arquivo // {}')
    template_tipo=$(printf '%s' "$CORPO" | jq -r '.template // "padrao"')
    analises_concluidas=$(printf '%s' "$CORPO" | jq -c '.analises_concluidas // []')
    hash_arquivo=$(printf '%s' "$CORPO" | jq -r '.hash_arquivo // ""')
    prompt_sistema=$(printf '%s' "$CORPO" | jq -r '.prompt_sistema // ""')
    prompt_usuario=$(printf '%s' "$CORPO" | jq -r '.prompt_usuario // ""')

    local caminho conteudo
    caminho=$(printf '%s' "$arquivo_dados" | jq -r '.caminho // "arquivo_desconhecido"')
    conteudo=$(printf '%s' "$arquivo_dados" | jq -r '.conteudo // ""')

    if [ -z "$conteudo" ] && [ -n "$caminho" ] && [ -f "$caminho" ]; then
        conteudo=$(cat "$caminho")
    fi

    if [ -z "$conteudo" ]; then
        enviar_erro 400 "Arquivo sem conteúdo para análise"
        return
    fi

    if [ -z "$hash_arquivo" ]; then
        hash_arquivo=$(calcular_hash_texto "$conteudo")
    fi

    if [ -n "$prompt_sistema" ] && [ -n "$prompt_usuario" ]; then
        local cache_existe
        if [ -n "$hash_arquivo" ]; then
            local cache
            cache=$(obter_analise_por_hash "$hash_arquivo")
            local cache_id
            cache_id=$(printf '%s' "$cache" | jq -r '.id // 0')

            if [ "$cache_id" != "0" ]; then
                local cache_interpretacao
                cache_interpretacao=$(printf '%s' "$cache" | jq -r '.interpretacao // ""')

                local resultado_cache
                resultado_cache=$(jq -n \
                    --arg status "cacheado" \
                    --argjson id "$cache_id" \
                    --arg resposta_bruta "$cache_interpretacao" \
                    --argjson cacheado true \
                    '{status: $status, id_analise: $id, resposta_bruta: $resposta_bruta, cacheado: $cacheado}')

                escrever_log_arquivo "INFO" "Cache hit: $caminho (hash: ${hash_arquivo:0:12})"
                enviar_json 200 "$resultado_cache"
                return
            fi
        fi

        local interpretacao
        if interpretacao=$(analisar_com_retry "$prompt_sistema" "$prompt_usuario" "$caminho" 2>/tmp/manipulador_erro_$$); then
            salvar_analise "$caminho" "$conteudo" "$interpretacao" "$hash_arquivo" 0 "negocio"
            local ultimo_id
            ultimo_id=$(obter_ultimo_id)

            local inicio fim duracao_ms
            inicio=$(date +%s%3N 2>/dev/null || echo 0)
            fim=$(date +%s%3N 2>/dev/null || echo 0)
            duracao_ms=$(( fim - inicio ))

            local resultado
            resultado=$(jq -n \
                --arg status "concluido" \
                --argjson id "$ultimo_id" \
                --arg resposta_bruta "$interpretacao" \
                --argjson cacheado false \
                --argjson tokens_usados 0 \
                --argjson duracao_ms "$duracao_ms" \
                '{status: $status, id_analise: $id, resposta_bruta: $resposta_bruta, cacheado: $cacheado, tokens_usados: $tokens_usados, duracao_ms: $duracao_ms}')

            enviar_json 200 "$resultado"
        else
            local erro_msg
            erro_msg=$(cat /tmp/manipulador_erro_$$ 2>/dev/null || echo "Erro na comunicação com Ollama")
            rm -f /tmp/manipulador_erro_$$

            escrever_log_arquivo "ERRO" "Falha na análise de $caminho: $erro_msg"
            enviar_erro 500 "$erro_msg"
        fi
    else
        local prompt_completo
        prompt_completo=$(construir_prompt_completo "$template_tipo" "$metadados" "$arquivo_dados" "$analises_concluidas")

        local sys_calculado usr_calculado
        sys_calculado=$(printf '%s' "$prompt_completo" | jq -r '.sistema // ""')
        usr_calculado=$(printf '%s' "$prompt_completo" | jq -r '.usuario // ""')

        if [ -z "$sys_calculado" ] || [ -z "$usr_calculado" ]; then
            enviar_erro 400 "Falha ao construir prompt. Verifique metadados e arquivo."
            return
        fi

        if [ -n "$hash_arquivo" ]; then
            local cache
            cache=$(obter_analise_por_hash "$hash_arquivo")
            local cache_id
            cache_id=$(printf '%s' "$cache" | jq -r '.id // 0')

            if [ "$cache_id" != "0" ]; then
                local cache_interpretacao
                cache_interpretacao=$(printf '%s' "$cache" | jq -r '.interpretacao // ""')

                local resultado_cache
                resultado_cache=$(jq -n \
                    --arg status "cacheado" \
                    --argjson id "$cache_id" \
                    --arg resposta_bruta "$cache_interpretacao" \
                    --argjson cacheado true \
                    '{status: $status, id_analise: $id, resposta_bruta: $resposta_bruta, cacheado: $cacheado}')

                escrever_log_arquivo "INFO" "Cache hit: $caminho (hash: ${hash_arquivo:0:12})"
                enviar_json 200 "$resultado_cache"
                return
            fi
        fi

        local interpretacao
        if interpretacao=$(analisar_com_retry "$sys_calculado" "$usr_calculado" "$caminho" 2>/tmp/manipulador_erro_$$); then
            salvar_analise "$caminho" "$conteudo" "$interpretacao" "$hash_arquivo" 0 "negocio"
            local ultimo_id
            ultimo_id=$(obter_ultimo_id)

            local resultado
            resultado=$(jq -n \
                --arg status "concluido" \
                --argjson id "$ultimo_id" \
                --arg resposta_bruta "$interpretacao" \
                --argjson cacheado false \
                '{status: $status, id_analise: $id, resposta_bruta: $resposta_bruta, cacheado: $cacheado}')

            enviar_json 200 "$resultado"
        else
            local erro_msg
            erro_msg=$(cat /tmp/manipulador_erro_$$ 2>/dev/null || echo "Erro na comunicação com Ollama")
            rm -f /tmp/manipulador_erro_$$

            escrever_log_arquivo "ERRO" "Falha na análise de $caminho: $erro_msg"
            enviar_erro 500 "$erro_msg"
        fi
    fi
}
