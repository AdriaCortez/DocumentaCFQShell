#!/usr/bin/env bash
set -euo pipefail

carregar_dependencias() {
    local base
    base="$(cd "$(dirname "$(readlink -e "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")")" && cd .. && pwd)"

    source "$base/../config.sh"
    source "$base/util/log.sh"
    source "$base/util/validacao.sh"
    source "$base/controle/banco.sh"
    source "$base/controle/eventos.sh"
    source "$base/llm/cliente.sh"
    source "$base/llm/retry.sh"
    source "$base/llm/prompt.sh"
}

extrair_imports_exports() {
    local caminho="$1"
    local conteudo
    conteudo=$(cat "$caminho" 2>/dev/null || echo "")

    local resultado=""
    local imports
    imports=$(printf '%s' "$conteudo" | grep -E '^(import |from |require\(|include |include_once |require_once |using |import\(|const .*require)' 2>/dev/null | head -30 || true)
    if [ -n "$imports" ]; then
        resultado+="IMPORTS:\n$imports\n"
    fi

    local exports
    exports=$(printf '%s' "$conteudo" | grep -E '^(export |module\.exports|def |class |function |public class|public function|public static|type |interface )' 2>/dev/null | head -20 || true)
    if [ -n "$exports" ]; then
        resultado+="EXPORTS:\n$exports\n"
    fi

    printf '%b' "$resultado"
}

extrair_conteudo_arquivos_principais() {
    local diretorio="$1"
    local -n arquivos_ref="$2"
    local resultado=""

    local padroes_chave=(
        "server.js" "server.ts" "index.js" "index.ts" "app.js" "app.ts" "app.tsx" "app.jsx"
        "routes.js" "routes.ts" "root.tsx" "root.jsx"
    )

    local total_extraido=0
    local max_extrair=6
    local linhas_max=80

    for padrao in "${padroes_chave[@]}"; do
        [ "$total_extraido" -ge "$max_extrair" ] && break

        for arquivo in "${arquivos_ref[@]}"; do
            [ "$total_extraido" -ge "$max_extrair" ] && break

            local nome_base
            nome_base=$(basename "$arquivo" 2>/dev/null || echo "")
            if [ "$nome_base" = "$padrao" ]; then
                local caminho_completo="$diretorio/$arquivo"
                if [ -f "$caminho_completo" ]; then
                    local linhas
                    linhas=$(wc -l < "$caminho_completo" 2>/dev/null || echo 0)
                    local limite_linhas="$linhas_max"
                    [ "$linhas" -lt "$linhas_max" ] 2>/dev/null && limite_linhas="$linhas"

                    local conteudo
                    conteudo=$(head -n "$limite_linhas" "$caminho_completo" 2>/dev/null || echo "")

                    if [ -n "$conteudo" ]; then
                        local ext
                        ext="${arquivo##*.}"
                        resultado+="=== $arquivo ===\n\`\`\`$ext\n$conteudo\n"
                        if [ "$linhas" -gt "$linhas_max" ] 2>/dev/null; then
                            resultado+="... (truncado, $((linhas - linhas_max)) linhas restantes)\n"
                        fi
                        resultado+="\`\`\`\n\n"
                        total_extraido=$((total_extraido + 1))
                    fi
                fi
            fi
        done
    done

    if [ -z "$resultado" ]; then
        resultado="(nenhum arquivo principal identificado para extração de conteúdo)"
    fi

    printf '%b' "$resultado"
}

montar_estrutura_dependencias() {
    local diretorio="$1"
    local -n arquivos_ref="$2"
    local resultado=""

    for arquivo in "${arquivos_ref[@]}"; do
        local caminho_completo="$diretorio/$arquivo"
        if [ -f "$caminho_completo" ]; then
            local deps
            deps=$(extrair_imports_exports "$caminho_completo")
            if [ -n "$deps" ]; then
                resultado+="=== $arquivo ===\n$deps\n"
            fi
        fi
    done

    printf '%b' "$resultado"
}

executar_analise_global() {
    local projeto_id="$1"
    local diretorio="$2"
    local arquivos_negocio_json="$3"

    local -a arquivos=()
    if [ -n "$arquivos_negocio_json" ] && [ "$arquivos_negocio_json" != "[]" ]; then
        while IFS= read -r linha; do
            [ -z "$linha" ] && continue
            arquivos+=("$linha")
        done < <(printf '%s' "$arquivos_negocio_json" | jq -r '.[]')
    fi

    local total=${#arquivos[@]}
    if [ "$total" -eq 0 ]; then
        exibir_aviso "Nenhum arquivo de negocio para analise global"
        return 1
    fi

    if [ "${HABILITAR_API:-false}" = "true" ]; then
        notificar_analise_global_iniciada "$total"
    fi

    local arvore
    arvore=$(printf '%s\n' "${arquivos[@]}" | sort)

    local imports_exports
    imports_exports=$(montar_estrutura_dependencias "$diretorio" arquivos)

    if [ -z "$imports_exports" ]; then
        imports_exports="(nenhum import/export detectado nos arquivos)"
    fi

    local conteudo_principal
    conteudo_principal=$(extrair_conteudo_arquivos_principais "$diretorio" arquivos)
    [ -z "$conteudo_principal" ] && conteudo_principal="(nenhum arquivo principal extraido)"

    local nome_projeto="Analise"
    local user_id="0"
    if [ -n "$projeto_id" ] && [ "$projeto_id" != "0" ] && [ "$projeto_id" != "null" ]; then
        nome_projeto=$(obter_projeto_por_id "$projeto_id" | jq -r '.nome // "Projeto"') || true
        [ -z "$nome_projeto" ] && nome_projeto="Projeto"
        user_id=$(obter_projeto_user_id "$projeto_id")
    fi

    local metadados
    metadados=$(jq -n \
        --arg nome "$nome_projeto" \
        --argjson arvore "$(printf '%s\n' "${arquivos[@]}" | jq -R -s 'split("\n") | map(select(length > 0))')" \
        '{nome_projeto: $nome, arvore_arquivos: $arvore}')

    local prompt_global
    if ! prompt_global=$(construir_prompt_global "$metadados" "$arvore" "$imports_exports" "$conteudo_principal"); then
        exibir_erro "Falha ao construir prompt global"
        if [ "${HABILITAR_API:-false}" = "true" ]; then
            notificar_analise_global_erro "Falha ao construir prompt global"
        fi
        return 1
    fi

    local sistema usuario
    sistema=$(printf '%s' "$prompt_global" | jq -r '.sistema')
    usuario=$(printf '%s' "$prompt_global" | jq -r '.usuario')

    if [ -z "$sistema" ] || [ -z "$usuario" ]; then
        exibir_erro "Prompt global invalido"
        if [ "${HABILITAR_API:-false}" = "true" ]; then
            notificar_analise_global_erro "Prompt global invalido"
        fi
        return 1
    fi

    exibir_info "Enviando analise global para o LLM ($total arquivos)..."

    local interpretacao=""
    if interpretacao=$(analisar_com_retry "$sistema" "$usuario" "analise_global" 2>/tmp/global_erro_$$); then
        if [ -n "$projeto_id" ] && [ "$projeto_id" != "0" ] && [ "$projeto_id" != "null" ]; then
            salvar_analise_global "$projeto_id" "$interpretacao" "$arvore" "$user_id" 2>/dev/null || true
        fi

        if [ "${HABILITAR_API:-false}" = "true" ]; then
            local analise_id
            analise_id=$(obter_ultimo_id_global)
            notificar_analise_global_concluida "$analise_id"
        fi

        printf '%s' "$interpretacao" 2>/dev/null || true
        return 0
    else
        local erro_msg
        erro_msg=$(cat /tmp/global_erro_$$ 2>/dev/null || echo "Erro desconhecido")
        rm -f /tmp/global_erro_$$

        exibir_erro "Falha na analise global: $erro_msg"
        if [ "${HABILITAR_API:-false}" = "true" ]; then
            notificar_analise_global_erro "$erro_msg"
        fi
        return 1
    fi
}

executar_analise_global_incremental() {
    local projeto_id="$1"
    local diretorio="$2"
    local analise_antiga="$3"
    local arquivos_json="$4"
    local secoes_afetadas="$5"

    local -a arquivos_modificados=()
    local -a tipos_modificados=()

    if [ -n "$arquivos_json" ] && [ "$arquivos_json" != "[]" ]; then
        local qtd
        qtd=$(printf '%s' "$arquivos_json" | jq 'length' 2>/dev/null || echo 0)
        for ((i=0; i<qtd; i++)); do
            local arq tipo
            arq=$(printf '%s' "$arquivos_json" | jq -r ".[$i].caminho // \"\"" 2>/dev/null)
            tipo=$(printf '%s' "$arquivos_json" | jq -r ".[$i].tipo // \"padrao\"" 2>/dev/null)
            [ -n "$arq" ] && arquivos_modificados+=("$arq")
            [ -n "$tipo" ] && tipos_modificados+=("$tipo")
        done
    fi

    local total_mod=${#arquivos_modificados[@]}
    if [ "$total_mod" -eq 0 ]; then
        exibir_aviso "Nenhum arquivo modificado para analise incremental"
        return 1
    fi

    local nome_projeto="Analise"
    if [ -n "$projeto_id" ] && [ "$projeto_id" != "0" ] && [ "$projeto_id" != "null" ]; then
        nome_projeto=$(obter_projeto_por_id "$projeto_id" | jq -r '.nome // "Projeto"') || true
        [ -z "$nome_projeto" ] && nome_projeto="Projeto"
    fi

    local lista_arquivos
    lista_arquivos=$(printf '%s\n' "${arquivos_modificados[@]}" | head -20)

    local sec_formatted=""
    if [ -n "$secoes_afetadas" ]; then
        sec_formatted=$(printf '%s' "$secoes_afetadas" | sed 's/^/  - /')
    fi

    local prompt_usuario
    prompt_usuario=$(cat <<EOF
=== ANÁLISE GLOBAL ANTERIOR ===
${analise_antiga}

=== ARQUIVOS MODIFICADOS/ADICIONADOS ===
${lista_arquivos}

=== INSTRUÇÕES ===
Os arquivos acima foram adicionados ou modificados neste projeto. Atualize APENAS as seguintes seções da análise global que são impactadas por estas mudanças:

${sec_formatted}

Para cada seção afetada:
1. Mantenha o formato original (cabeçalhos, marcações [FATO]/[A VALIDAR]/[INFERÊNCIA])
2. Atualize o conteúdo com base nos novos arquivos
3. Se o arquivo modificado invalidar uma conclusão anterior, corrija-a
4. Se o arquivo modificado adicionar novas informações, inclua-as

IMPORTANTE:
- NÃO altere seções que não estão na lista acima — mantenha-as IDÊNTICAS
- NÃO remova seções que já existiam
- Mantenha TODAS as 26 seções do documento original
- Atualize também o Sumário Executivo para refletir as mudanças

Responda com a análise global COMPLETA (todas as seções), com as seções afetadas atualizadas.
EOF
)

    local prompt_sistema
    prompt_sistema=$(carregar_template_sistema)

    local saida_arquivo erro_arquivo
    saida_arquivo=$(mktemp)
    erro_arquivo=$(mktemp)

    exibir_info "Enviando analise global incremental ($total_mod arquivos modificados)..."
    chamar_ollama "$prompt_sistema" "$prompt_usuario" "$saida_arquivo" "$erro_arquivo"
    local codigo=$?

    if [ $codigo -eq 0 ] && [ -s "$saida_arquivo" ]; then
        local interpretacao
        interpretacao=$(cat "$saida_arquivo")
        rm -f "$saida_arquivo" "$erro_arquivo"

        if [ -n "$projeto_id" ] && [ "$projeto_id" != "0" ] && [ "$projeto_id" != "null" ]; then
            local user_id
            user_id=$(obter_projeto_user_id "$projeto_id")
            local arvore
            arvore=$(printf '%s\n' "${arquivos_modificados[@]}" | sort)
            salvar_analise_global "$projeto_id" "$interpretacao" "$arvore" "$user_id" 2>/dev/null || true
        fi

        printf '%s' "$interpretacao"
        return 0
    else
        rm -f "$saida_arquivo" "$erro_arquivo"
        exibir_erro "Falha na analise global incremental"
        return 1
    fi
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    ARQUIVOS_NEGOCIO_JSON="${1:-[]}"
    DIRETORIO_ALVO="${2:-.}"
    PROJETO_ID="${3:-0}"
    HABILITAR_API="${HABILITAR_API:-false}"
    carregar_dependencias
    validar_dependencias >/dev/null 2>&1 || true
    verificar_ollama >/dev/null 2>&1 || { exibir_erro "Ollama nao acessivel"; exit 1; }
    inicializar_banco >/dev/null 2>&1 || true
    executar_analise_global "$PROJETO_ID" "$DIRETORIO_ALVO" "$ARQUIVOS_NEGOCIO_JSON"
fi
