#!/usr/bin/env bash
set -euo pipefail

# ─── Orquestrador principal de análise ───
# Uso: analisar.sh [diretório_alvo]

DIRETORIO_ALVO="${1:-.}"

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
    source "$base/analise/executor.sh"
    source "$base/analise/analisador_global.sh"
}

carregar_dependencias

trap '' PIPE HUP

validar_dependencias

verificar_ollama || exit 1

exibir_info "Buscando arquivos em '$DIRETORIO_ALVO'..."

declare -a ARQUIVOS_ENCONTRADOS=()
while IFS= read -r arquivo; do
    [ -z "$arquivo" ] && continue
    ARQUIVOS_ENCONTRADOS+=("$arquivo")
done < <(coletar_arquivos "$DIRETORIO_ALVO")

TOTAL_ENCONTRADOS=${#ARQUIVOS_ENCONTRADOS[@]}

if [ "$TOTAL_ENCONTRADOS" -eq 0 ]; then
    exibir_info "Nenhum arquivo de código encontrado no diretório."
    exit 0
fi

exibir_info "$TOTAL_ENCONTRADOS arquivo(s) encontrado(s)"

inicializar_banco
inicializar_controle

HABILITAR_API="${HABILITAR_API:-true}"
if [ "$HABILITAR_API" = "true" ]; then
    definir_status "executando"
    definir_pid "$$"
    inicializar_eventos
    trap 'definir_status "parado"; [ -f "$ARQUIVO_EVENTOS" ] && notificar_finalizado 0 0 0 "Análise interrompida"; limpar_controle; exit' EXIT INT TERM
fi

exibir_info "Classificando arquivos..."

CLASSIFICACAO=$(classificar_lote "${ARQUIVOS_ENCONTRADOS[@]}")

ARQUIVOS_NEGOCIO=()
while IFS= read -r linha; do
    [ -z "$linha" ] && continue
    ARQUIVOS_NEGOCIO+=("$linha")
done < <(printf '%s' "$CLASSIFICACAO" | jq -r '.negocio[]')

TOTAL_IGNORADOS=$(printf '%s' "$CLASSIFICACAO" | jq -r '.ignorados.arquivos | length')
TOTAL_NEGOCIO=${#ARQUIVOS_NEGOCIO[@]}

exibir_info "$TOTAL_NEGOCIO arquivo(s) de negócio, $TOTAL_IGNORADOS ignorado(s)"

if [ "$HABILITAR_API" = "true" ] && [ "$TOTAL_NEGOCIO" -gt 0 ]; then
    definir_fila "${ARQUIVOS_NEGOCIO[@]}"
fi

if [ "$TOTAL_IGNORADOS" -gt 0 ]; then
    i=0
    while [ $i -lt "$TOTAL_IGNORADOS" ]; do
        arq_ign=$(printf '%s' "$CLASSIFICACAO" | jq -r ".ignorados.arquivos[$i]")
        motiv_ign=$(printf '%s' "$CLASSIFICACAO" | jq -r ".ignorados.motivos[$i]")
        salvar_ignorado "$arq_ign" "$motiv_ign"
        i=$((i + 1))
    done
fi

if [ "$TOTAL_NEGOCIO" -eq 0 ]; then
    exibir_info "Nenhum arquivo de negócio encontrado para análise."
    if [ "$HABILITAR_API" = "true" ]; then
        notificar_finalizado 0 "$TOTAL_IGNORADOS" 0 "Nenhum arquivo de negócio encontrado"
    fi
    exit 0
fi

exibir_info "Verificando arquivos já analisados..."

cd "$DIRETORIO_ALVO"
FILTRAGEM=$(filtar_arquivos_nao_analisados "${ARQUIVOS_NEGOCIO[@]}")

ARQUIVOS_PENDENTES=()
while IFS= read -r linha; do
    [ -z "$linha" ] && continue
    ARQUIVOS_PENDENTES+=("$linha")
done < <(printf '%s' "$FILTRAGEM" | jq -r '.pendentes[]')

HASHES_PENDENTES=()
while IFS= read -r linha; do
    [ -z "$linha" ] && continue
    HASHES_PENDENTES+=("$linha")
done < <(printf '%s' "$FILTRAGEM" | jq -r '.hashes[]')

PULADOS=$(printf '%s' "$FILTRAGEM" | jq -r '.pulados')
TOTAL_PENDENTES=${#ARQUIVOS_PENDENTES[@]}

if [ "$PULADOS" -gt 0 ]; then
    exibir_info "$PULADOS arquivo(s) já analisado(s) — $TOTAL_PENDENTES pendente(s)"
fi

if [ "$TOTAL_PENDENTES" -eq 0 ]; then
    exibir_info "Todos os arquivos de negócio já foram analisados anteriormente."
    if [ "$HABILITAR_API" = "true" ]; then
        notificar_finalizado 0 0 0 "Todos os arquivos já analisados anteriormente"
    fi
    exit 0
fi

exibir_info "Analisando $TOTAL_PENDENTES arquivo(s) de negócio"

ANALISE_GLOBAL=""

exibir_info "Executando analise global..."

arquivos_negocio_json=$(printf '%s\n' "${ARQUIVOS_NEGOCIO[@]}" | jq -R -s 'split("\n") | map(select(length > 0))')

if ANALISE_GLOBAL=$(executar_analise_global "0" "$DIRETORIO_ALVO" "$arquivos_negocio_json"); then
    exibir_sucesso "Analise global concluida"
else
    exibir_erro "Falha na analise global. Interrompendo."
    if [ "${HABILITAR_API:-true}" = "true" ]; then
        notificar_erro "GLOBAL_ANALYSIS_FAILED" "Falha na analise global"
        definir_status "parado"
        limpar_controle
    fi
    exit 1
fi

SUCESSOS=0
ERROS=0

for i in "${!ARQUIVOS_PENDENTES[@]}"; do
    ARQUIVO="${ARQUIVOS_PENDENTES[$i]}"
    HASH="${HASHES_PENDENTES[$i]}"

    if [ "$HABILITAR_API" = "true" ] && aguardar_parada; then
        exibir_aviso "Parada solicitada. Interrompendo análise..."
        break
    fi

    definir_progresso "$i" "$TOTAL_PENDENTES" "$ARQUIVO"

    if [ -r "$ARQUIVO" ]; then
        CONTEUDO=$(cat "$ARQUIVO")

        DADOS_ARQUIVO=$(jq -n \
            --arg caminho "$ARQUIVO" \
            --arg tipo "$(classificar_tipo_arquivo "$ARQUIVO")" \
            --arg linguagem "$(obter_extensao_arquivo "$ARQUIVO")" \
            --arg conteudo "$CONTEUDO" \
            '{caminho: $caminho, tipo: $tipo, linguagem: $linguagem, conteudo: $conteudo, imports: [], exports: []}')

        PROMPT_COMPLETO=$(construir_prompt_completo "padrao" '{"nome_projeto": "Analise"}' "$DADOS_ARQUIVO" "[]" "$ANALISE_GLOBAL")

        SISTEMA=$(printf '%s' "$PROMPT_COMPLETO" | jq -r '.sistema')
        USUARIO=$(printf '%s' "$PROMPT_COMPLETO" | jq -r '.usuario')

        if [ -z "$SISTEMA" ] || [ -z "$USUARIO" ]; then
            exibir_erro "Prompt invalido para $ARQUIVO — resposta do template malformada"
            ERROS=$((ERROS + 1))
            continue
        fi

        RESULTADO=$(executar_analise_arquivo "$ARQUIVO" "$HASH" "$SISTEMA" "$USUARIO" "$i" "$TOTAL_PENDENTES")

        STATUS=$(printf '%s' "$RESULTADO" | jq -r '.status')

        if [ "$STATUS" = "sucesso" ]; then
            SUCESSOS=$((SUCESSOS + 1))
        else
            ERROS=$((ERROS + 1))
        fi
    else
        exibir_erro "Erro ao ler $ARQUIVO: sem permissão"
        ERROS=$((ERROS + 1))
    fi

    PERCENTUAL=0
    [ "$TOTAL_PENDENTES" -gt 0 ] 2>/dev/null && PERCENTUAL=$(( ((i + 1) * 100) / TOTAL_PENDENTES ))

    if [ "$HABILITAR_API" = "true" ]; then
        PAYLOAD=$(jq -n --argjson atual "$((i + 1))" --argjson total "$TOTAL_PENDENTES" --argjson percentual "$PERCENTUAL" \
            '{atual: $atual, total: $total, percentual: $percentual}')
        escrever_evento "progresso" "$PAYLOAD"
    fi

    if [ $((i + 1)) -lt "$TOTAL_PENDENTES" ]; then
        sleep 1
    fi
done

exibir_info "Análise concluída: $SUCESSOS sucesso(s), $ERROS erro(s), $TOTAL_IGNORADOS ignorado(s)"

if [ "$HABILITAR_API" = "true" ]; then
    notificar_finalizado "$SUCESSOS" "$ERROS" "$TOTAL_IGNORADOS" ""
    definir_status "parado"
    limpar_controle
fi
