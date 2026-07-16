#!/usr/bin/env bash
set -euo pipefail

PROJETO_ID="${1:-}"
DIRETORIO_ALVO="${2:-.}"

carregar_dependencias() {
    local base
    base="$(cd "$(dirname "$(readlink -e "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")")" && cd .. && pwd)"

    source "$base/../config.sh"
    source "$base/util/log.sh"
    source "$base/util/validacao.sh"
    source "$base/controle/estado.sh"
    source "$base/controle/progresso.sh"
    source "$base/controle/eventos.sh"
    source "$base/controle/fila.sh"
    source "$base/controle/banco.sh"
    source "$base/llm/cliente.sh"
    source "$base/llm/retry.sh"
    source "$base/llm/prompt.sh"
    source "$base/analise/classificador.sh"
    source "$base/analise/coletor.sh"
    source "$base/analise/analisador_global.sh"
}

carregar_dependencias

trap '' PIPE HUP

if [ -z "$PROJETO_ID" ]; then
    exibir_erro "ID do projeto nao informado"
    exit 1
fi
validar_dependencias

verificar_ollama || exit 1

inicializar_banco

exibir_info "Analisando projeto #$PROJETO_ID em '$DIRETORIO_ALVO'..."

declare -a ARQUIVOS_PENDENTES=()
declare -a IDS_ARQUIVOS=()

arquivos_json=$(listar_arquivos_projeto "$PROJETO_ID")
while IFS= read -r linha; do
    [ -z "$linha" ] && continue
    local_id=$(printf '%s' "$linha" | jq -r '.id')
    local_caminho=$(printf '%s' "$linha" | jq -r '.caminho_relativo')
    local_status=$(printf '%s' "$linha" | jq -r '.status')

    if [ "$local_status" = "pendente" ] || [ "$local_status" = "erro" ] || [ "$local_status" = "analisando" ]; then
        IDS_ARQUIVOS+=("$local_id")
        ARQUIVOS_PENDENTES+=("$local_caminho")
    fi
done < <(printf '%s' "$arquivos_json" | jq -c '.[]')

TOTAL_PENDENTES=${#ARQUIVOS_PENDENTES[@]}

if [ "$TOTAL_PENDENTES" -eq 0 ]; then
    exibir_info "Nenhum arquivo pendente para analisar no projeto."
    atualizar_projeto_status "$PROJETO_ID" "concluido"
    exit 0
fi

exibir_info "$TOTAL_PENDENTES arquivo(s) pendente(s) para analise"

HABILITAR_API="${HABILITAR_API:-true}"
if [ "$HABILITAR_API" = "true" ]; then
    definir_status "executando"
    definir_pid "$$"
    inicializar_eventos
    trap 'atualizar_projeto_status "$PROJETO_ID" "parado"; definir_status "parado"; [ -f "$ARQUIVO_EVENTOS" ] && notificar_finalizado 0 0 0 "Analise interrompida"; limpar_controle; exit' EXIT INT TERM
fi

nome_projeto=$(obter_projeto_por_id "$PROJETO_ID" | jq -r '.nome // "Projeto"')
projeto_user_id=$(obter_projeto_user_id "$PROJETO_ID")

cd "$DIRETORIO_ALVO"

SUCESSOS=0
ERROS=0
IGNORADOS=0
ANALISES_CONCLUIDAS="[]"
ANALISE_GLOBAL=""

exibir_info "Executando analise global do projeto..."

arquivos_negocio_json=$(printf '%s\n' "${ARQUIVOS_PENDENTES[@]}" | jq -R -s 'split("\n") | map(select(length > 0))')

TOTAL_ARQUIVOS_PROJETO=$(printf '%s' "$arquivos_json" | jq 'length' 2>/dev/null || echo "$TOTAL_PENDENTES")
ANALISE_GLOBAL_EXISTENTE=$(obter_analise_global_projeto "$PROJETO_ID" 2>/dev/null || echo "null")
ANALISE_ANTIGA=""
if [ "$ANALISE_GLOBAL_EXISTENTE" != "null" ] && [ -n "$ANALISE_GLOBAL_EXISTENTE" ]; then
    ANALISE_ANTIGA=$(printf '%s' "$ANALISE_GLOBAL_EXISTENTE" | jq -r '.interpretacao // ""' 2>/dev/null || echo "")
fi

USAR_INCREMENTAL=false
if [ -n "$ANALISE_ANTIGA" ] && [ "$TOTAL_PENDENTES" -gt 0 ] && [ "$TOTAL_ARQUIVOS_PROJETO" -gt 0 ]; then
    METADE=$((TOTAL_ARQUIVOS_PROJETO / 2))
    if [ "$TOTAL_PENDENTES" -lt "$METADE" ]; then
        USAR_INCREMENTAL=true
    fi
fi

if [ "$USAR_INCREMENTAL" = "true" ]; then
    exibir_info "Poucos arquivos modificados ($TOTAL_PENDENTES de $TOTAL_ARQUIVOS_PROJETO). Usando analise global incremental..."
    
    ARQUIVOS_MOD_JSON="["
    PRIMEIRO=true
    for arq in "${ARQUIVOS_PENDENTES[@]}"; do
        TIPO_ARQ=$(classificar_tipo_arquivo "$arq" 2>/dev/null || echo "padrao")
        if [ "$PRIMEIRO" = "true" ]; then
            PRIMEIRO=false
        else
            ARQUIVOS_MOD_JSON+=","
        fi
        ARQUIVOS_MOD_JSON+="{\"caminho\":\"$arq\",\"tipo\":\"$TIPO_ARQ\"}"
    done
    ARQUIVOS_MOD_JSON+="]"
    
    if ANALISE_GLOBAL=$(executar_analise_global_incremental "$PROJETO_ID" "$DIRETORIO_ALVO" "$ANALISE_ANTIGA" "$ARQUIVOS_MOD_JSON" ""); then
        exibir_sucesso "Analise global incremental concluida"
    else
        exibir_aviso "Falha na analise incremental. Tentando analise completa..."
        if ANALISE_GLOBAL=$(executar_analise_global "$PROJETO_ID" "$DIRETORIO_ALVO" "$arquivos_negocio_json"); then
            exibir_sucesso "Analise global concluida"
        else
            exibir_erro "Falha na analise global. Interrompendo analise do projeto."
            atualizar_projeto_status "$PROJETO_ID" "erro_global"
            if [ "${HABILITAR_API:-true}" = "true" ]; then
                notificar_erro "GLOBAL_ANALYSIS_FAILED" "Falha na analise global do projeto"
                definir_status "parado"
                limpar_controle
            fi
            exit 1
        fi
    fi
else
    if ANALISE_GLOBAL=$(executar_analise_global "$PROJETO_ID" "$DIRETORIO_ALVO" "$arquivos_negocio_json"); then
        exibir_sucesso "Analise global concluida"
    else
        exibir_erro "Falha na analise global. Interrompendo analise do projeto."
        atualizar_projeto_status "$PROJETO_ID" "erro_global"
        if [ "${HABILITAR_API:-true}" = "true" ]; then
            notificar_erro "GLOBAL_ANALYSIS_FAILED" "Falha na analise global do projeto"
            definir_status "parado"
            limpar_controle
        fi
        exit 1
    fi
fi

for i in "${!ARQUIVOS_PENDENTES[@]}"; do
    ARQUIVO="${ARQUIVOS_PENDENTES[$i]}"
    ARQUIVO_DB_ID="${IDS_ARQUIVOS[$i]}"
    CAMINHO_COMPLETO="$DIRETORIO_ALVO/$ARQUIVO"

    if [ "$HABILITAR_API" = "true" ] && aguardar_parada; then
        exibir_aviso "Parada solicitada. Interrompendo analise..."
        break
    fi

    definir_progresso "$i" "$TOTAL_PENDENTES" "$ARQUIVO"

    if [ "$HABILITAR_API" = "true" ]; then
        PAYLOAD_ARQ=$(jq -n \
            --arg arquivo "$ARQUIVO" \
            --argjson indice "$i" \
            --argjson total "$TOTAL_PENDENTES" \
            --arg status "analisando" \
            '{arquivo: $arquivo, indice: $indice, total: $total, status: $status}')
        escrever_evento "progresso_arquivo" "$PAYLOAD_ARQ"
    fi

    atualizar_arquivo_projeto_status "$ARQUIVO_DB_ID" "analisando"

    if [ ! -f "$CAMINHO_COMPLETO" ] || [ ! -r "$CAMINHO_COMPLETO" ]; then
        exibir_erro "Arquivo nao encontrado ou sem permissao: $ARQUIVO"
        atualizar_arquivo_projeto_status "$ARQUIVO_DB_ID" "erro"
        ERROS=$((ERROS + 1))
        continue
    fi

    local_classificacao=$(classificar_arquivo "$ARQUIVO")
    if [ "$local_classificacao" != "negocio" ]; then
        exibir_info "Ignorando $ARQUIVO ($local_classificacao)"
        if salvar_ignorado "$ARQUIVO" "$local_classificacao" "$PROJETO_ID" "$projeto_user_id" 2>/dev/null; then
            atualizar_arquivo_projeto_status "$ARQUIVO_DB_ID" "analisado"
            incrementar_arquivos_analisados "$PROJETO_ID"
        else
            exibir_erro "Falha ao salvar arquivo ignorado no banco: $ARQUIVO"
            atualizar_arquivo_projeto_status "$ARQUIVO_DB_ID" "erro"
        fi
        IGNORADOS=$((IGNORADOS + 1))
        continue
    fi

    CONTEUDO=$(cat "$CAMINHO_COMPLETO")
    HASH=$(calcular_hash "$CAMINHO_COMPLETO")

    if [ -n "$HASH" ] && verificar_hash_existe "$HASH" "$projeto_user_id"; then
        exibir_cache "$ARQUIVO"
        cache_result=$(obter_analise_por_hash "$HASH" "$projeto_user_id")
        cache_id=$(printf '%s' "$cache_result" | jq -r '.id // 0')

        if [ "$cache_id" != "0" ]; then
            sqlite3 -cmd ".output /dev/null" -cmd "PRAGMA journal_mode=WAL;" -cmd "PRAGMA busy_timeout=30000;" -cmd ".output stdout" "$ARQUIVO_BANCO" "UPDATE analises SET projeto_id=$PROJETO_ID WHERE id=$cache_id AND projeto_id IS NULL;" 2>/dev/null || true
            atualizar_arquivo_projeto_status "$ARQUIVO_DB_ID" "analisado" "$cache_id"
            incrementar_arquivos_analisados "$PROJETO_ID"
            SUCESSOS=$((SUCESSOS + 1))

            cache_resumo=$(printf '%s' "$cache_result" | jq -r '.interpretacao // ""' | head -c 200)
            ANALISES_CONCLUIDAS=$(printf '%s' "$ANALISES_CONCLUIDAS" | jq --arg arq "$ARQUIVO" --arg res "$cache_resumo" '. + [{arquivo: $arq, resumo: $res}]')
            continue
        fi
    fi

    DADOS_ARQUIVO=$(jq -n \
        --arg caminho "$ARQUIVO" \
        --arg tipo "$(classificar_tipo_arquivo "$ARQUIVO")" \
        --arg linguagem "$(obter_extensao_arquivo "$ARQUIVO")" \
        --arg conteudo "$CONTEUDO" \
        '{caminho: $caminho, tipo: $tipo, linguagem: $linguagem, conteudo: $conteudo, imports: [], exports: []}')

    METADADOS_PROJETO=$(jq -n \
        --arg nome "$nome_projeto" \
        --argjson arvore "$(printf '%s\n' "${ARQUIVOS_PENDENTES[@]}" | jq -R -s 'split("\n") | map(select(length > 0))')" \
        '{nome_projeto: $nome, arvore_arquivos: $arvore}')

    PROMPT_COMPLETO=$(construir_prompt_completo "padrao" "$METADADOS_PROJETO" "$DADOS_ARQUIVO" "$ANALISES_CONCLUIDAS" "$ANALISE_GLOBAL")

    SISTEMA=$(printf '%s' "$PROMPT_COMPLETO" | jq -r '.sistema')
    USUARIO=$(printf '%s' "$PROMPT_COMPLETO" | jq -r '.usuario')

    if [ -z "$SISTEMA" ] || [ -z "$USUARIO" ]; then
        exibir_erro "Prompt invalido para $ARQUIVO — resposta do template malformada"
        ERROS=$((ERROS + 1))
        atualizar_arquivo_projeto_status "$ARQUIVO_DB_ID" "erro"
        continue
    fi

    exibir_progresso "$i" "$TOTAL_PENDENTES" "$ARQUIVO"

    interpretacao=""
    if interpretacao=$(analisar_com_retry "$SISTEMA" "$USUARIO" "$ARQUIVO" 2>/tmp/proj_erro_$$); then
        if salvar_analise "$ARQUIVO" "$CONTEUDO" "$interpretacao" "$HASH" 0 "negocio" "$PROJETO_ID" "$projeto_user_id" 2>/dev/null; then
            analise_id=$(obter_ultimo_id)

            SUCESSOS=$((SUCESSOS + 1))
            atualizar_arquivo_projeto_status "$ARQUIVO_DB_ID" "analisado" "$analise_id"
            incrementar_arquivos_analisados "$PROJETO_ID"

            resumo=$(printf '%s' "$interpretacao" | head -c 200)
            ANALISES_CONCLUIDAS=$(printf '%s' "$ANALISES_CONCLUIDAS" | jq --arg arq "$ARQUIVO" --arg res "$resumo" '. + [{arquivo: $arq, resumo: $res}]')
        else
            exibir_erro "Falha ao persistir analise no banco: $ARQUIVO"
            ERROS=$((ERROS + 1))
            atualizar_arquivo_projeto_status "$ARQUIVO_DB_ID" "erro"
        fi
    else
        erro_msg=$(cat /tmp/proj_erro_$$ 2>/dev/null || echo "Erro desconhecido")
        rm -f /tmp/proj_erro_$$

        exibir_erro "Falha ao analisar: $ARQUIVO -- $erro_msg"
        ERROS=$((ERROS + 1))
        atualizar_arquivo_projeto_status "$ARQUIVO_DB_ID" "erro"
    fi

    PERCENTUAL=0
    [ "$TOTAL_PENDENTES" -gt 0 ] 2>/dev/null && PERCENTUAL=$(( ((i + 1) * 100) / TOTAL_PENDENTES ))

    if [ "$HABILITAR_API" = "true" ]; then
        PAYLOAD=$(jq -n \
            --argjson atual "$((i + 1))" \
            --argjson total "$TOTAL_PENDENTES" \
            --argjson percentual "$PERCENTUAL" \
            '{atual: $atual, total: $total, percentual: $percentual}')
        escrever_evento "progresso" "$PAYLOAD"
    fi

    if [ $((i + 1)) -lt "$TOTAL_PENDENTES" ]; then
        sleep 1
    fi
done

exibir_info "Analise do projeto #$PROJETO_ID concluida: $SUCESSOS sucesso(s), $ERROS erro(s), $IGNORADOS ignorado(s)"

if [ "$HABILITAR_API" = "true" ]; then
    trap - EXIT INT TERM
    notificar_finalizado "$SUCESSOS" "$ERROS" "$IGNORADOS" "Projeto #$PROJETO_ID"

    if [ "$ERROS" -eq 0 ]; then
        atualizar_projeto_status "$PROJETO_ID" "concluido"
    else
        atualizar_projeto_status "$PROJETO_ID" "concluido_com_erros"
    fi

    definir_status "parado"
    limpar_controle
    rm -f "$ARQUIVO_PROJETO_ATUAL"
    rm -f "$DIRETORIO_CONTROLE/projeto_${PROJETO_ID}_arquivos.json"
fi
