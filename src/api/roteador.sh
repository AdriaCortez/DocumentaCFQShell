#!/usr/bin/env bash

export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:${PATH:-}"

# ─── Carregar dependências ───
DIRETORIO_SCRIPT="${DIRETORIO_SCRIPT_RAIZ:-$(cd "$(dirname "$(readlink -e "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")")" && cd ../.. && pwd)}"

source "$DIRETORIO_SCRIPT/config.sh"
source "$DIRETORIO_SCRIPT/src/util/log.sh"
source "$DIRETORIO_SCRIPT/src/util/validacao.sh"
source "$DIRETORIO_SCRIPT/src/controle/estado.sh"
source "$DIRETORIO_SCRIPT/src/controle/progresso.sh"
source "$DIRETORIO_SCRIPT/src/controle/eventos.sh"
source "$DIRETORIO_SCRIPT/src/controle/fila.sh"
source "$DIRETORIO_SCRIPT/src/controle/banco.sh"
source "$DIRETORIO_SCRIPT/src/llm/cliente.sh"
source "$DIRETORIO_SCRIPT/src/llm/retry.sh"
source "$DIRETORIO_SCRIPT/src/llm/prompt.sh"
source "$DIRETORIO_SCRIPT/src/analise/coletor.sh"
source "$DIRETORIO_SCRIPT/src/analise/classificador.sh"

BASE_MANIPULADORES="$DIRETORIO_SCRIPT/src/api/manipuladores"

# ─── Variáveis da requisição ───
declare METODO=""
declare CAMINHO=""
declare -A CABECALHOS=()
declare CORPO=""

# ─── Parse da requisição HTTP ───
interpretar_requisicao() {
    local linha chave valor

    IFS= read -r linha || { enviar_erro 400 "Requisição vazia"; exit 0; }
    linha="${linha%$'\r'}"

    METODO="${linha%% *}"
    local restante="${linha#* }"
    CAMINHO="${restante%% *}"

    while IFS= read -r linha; do
        linha="${linha%$'\r'}"
        [ -z "$linha" ] && break
        chave="${linha%%:*}"
        valor="${linha#*:}"
        valor="${valor# }"
        CABECALHOS["${chave,,}"]="$valor"
    done

    local tamanho_conteudo="${CABECALHOS[content-length]:-}"
    if [ -n "$tamanho_conteudo" ] && [ "$tamanho_conteudo" -gt 0 ] 2>/dev/null; then
        local max_payload=$(( TAMANHO_MAX_ZIP_BYTES * 137 / 100 ))
        if [ "$tamanho_conteudo" -gt "$max_payload" ] 2>/dev/null; then
            local corpo_erro
            corpo_erro=$(jq -n --arg mensagem "Payload excede o limite maximo de ${TAMANHO_MAX_ZIP_MB}MB" --argjson codigo 413 '{erro: $mensagem, codigo: $codigo}')
            enviar_json 413 "$corpo_erro"
            exit 0
        fi
        local limite_variavel=$((10 * 1024 * 1024))
        if [ "$tamanho_conteudo" -ge "$limite_variavel" ] 2>/dev/null; then
            CORPO_FILE=$(mktemp /tmp/api_body_XXXXXX)
            head -c "$tamanho_conteudo" > "$CORPO_FILE" 2>/dev/null
            CORPO=""
        else
            CORPO=$(head -c "$tamanho_conteudo" 2>/dev/null || true)
            CORPO_FILE=""
        fi
    else
        CORPO=""
    fi
}

# ─── Funções de resposta HTTP ───
enviar_resposta() {
    local status="$1"
    local tipo_conteudo="$2"
    local corpo="${3:-}"
    local extras="${4:-}"

    local texto_status
    case "$status" in
        200) texto_status="OK" ;;
        201) texto_status="Created" ;;
        204) texto_status="No Content" ;;
        400) texto_status="Bad Request" ;;
        404) texto_status="Not Found" ;;
        405) texto_status="Method Not Allowed" ;;
        409) texto_status="Conflict" ;;
        500) texto_status="Internal Server Error" ;;
        *)   texto_status="Unknown" ;;
    esac

    printf "HTTP/1.1 %s %s\r\n" "$status" "$texto_status"
    printf "Content-Type: %s\r\n" "$tipo_conteudo"
    printf "Access-Control-Allow-Origin: *\r\n"
    printf "Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS\r\n"
    printf "Access-Control-Allow-Headers: Content-Type, X-User-Id\r\n"

    if [ -n "$extras" ]; then
        printf "%s\r\n" "$extras"
    fi

    if [ "$status" -eq 204 ] || [ -z "$corpo" ]; then
        printf "Content-Length: 0\r\n\r\n"
    else
        local tamanho
        tamanho=$(printf '%s' "$corpo" | wc -c)
        printf "Content-Length: %s\r\n\r\n%s" "$tamanho" "$corpo"
    fi
}

enviar_json() {
    local corpo_param="${2:-}"
    if [ -z "$corpo_param" ]; then
        corpo_param="{}"
    fi
    enviar_resposta "${1:-200}" "application/json" "$corpo_param"
}

enviar_erro() {
    local status="${1:-500}"
    local mensagem="${2:-Erro interno}"
    local corpo
    corpo=$(jq -n --arg mensagem "$mensagem" --argjson codigo "$status" \
        '{erro: $mensagem, codigo: $codigo}')
    enviar_json "$status" "$corpo"
}

# ─── Roteador ───
rotear() {
    case "$METODO" in
        OPTIONS)
            enviar_resposta 204 "text/plain" "" ;;

        GET)
            case "$CAMINHO" in
                /api/v1/status | /api/status)
                    source "$BASE_MANIPULADORES/manipulador_status.sh"
                    tratar_status ;;
                /api/v1/progresso | /api/progresso)
                    source "$BASE_MANIPULADORES/manipulador_progresso.sh"
                    tratar_progresso ;;
                /api/v1/analises | /api/analises)
                    source "$BASE_MANIPULADORES/manipulador_analises.sh"
                    tratar_listar_analises ;;
                /api/v1/analises/ultima | /api/analises/ultima)
                    source "$BASE_MANIPULADORES/manipulador_analises.sh"
                    tratar_ultima_analise ;;
                /api/v1/estatisticas | /api/estatisticas)
                    source "$BASE_MANIPULADORES/manipulador_analises.sh"
                    tratar_estatisticas ;;
                /api/v1/stream | /api/stream)
                    source "$BASE_MANIPULADORES/manipulador_stream.sh"
                    tratar_stream ;;
                /api/v1/fila | /api/fila)
                    source "$BASE_MANIPULADORES/manipulador_fila.sh"
                    tratar_fila ;;
                /api/v1/projetos | /api/projetos)
                    source "$BASE_MANIPULADORES/manipulador_projetos.sh"
                    tratar_listar_projetos ;;
                /api/v1/projetos/*/progresso | /api/projetos/*/progresso)
                    local caminho_base="$CAMINHO"
                    caminho_base="${caminho_base#/api/v1/projetos/}"
                    caminho_base="${caminho_base#/api/projetos/}"
                    local id="${caminho_base%%/progresso}"
                    source "$BASE_MANIPULADORES/manipulador_projetos.sh"
                    tratar_progresso_projeto "$id" ;;
                /api/v1/projetos/*/analise-global | /api/projetos/*/analise-global)
                    local caminho_base="$CAMINHO"
                    caminho_base="${caminho_base#/api/v1/projetos/}"
                    caminho_base="${caminho_base#/api/projetos/}"
                    local id="${caminho_base%%/analise-global}"
                    source "$BASE_MANIPULADORES/manipulador_projetos.sh"
                    tratar_analise_global_projeto "$id" ;;
                /api/v1/projetos/* | /api/projetos/*)
                    local caminho_base="$CAMINHO"
                    caminho_base="${caminho_base#/api/v1/projetos/}"
                    caminho_base="${caminho_base#/api/projetos/}"
                    local id="${caminho_base%%/*}"
                    if [ "$id" = "$caminho_base" ]; then
                        source "$BASE_MANIPULADORES/manipulador_projetos.sh"
                        tratar_obter_projeto "$id"
                    else
                        enviar_erro 404 "Rota nao encontrada"
                    fi ;;
                /api/v1/analises/arquivo/* | /api/analises/arquivo/*)
                    local nome="${CAMINHO#/api/v1/analises/arquivo/}"
                    nome="${nome#/api/analises/arquivo/}"
                    source "$BASE_MANIPULADORES/manipulador_analises.sh"
                    tratar_analise_por_arquivo "$nome" ;;
                /api/v1/analises/* | /api/analises/*)
                    local id="${CAMINHO#/api/v1/analises/}"
                    id="${id#/api/analises/}"
                    source "$BASE_MANIPULADORES/manipulador_analises.sh"
                    tratar_analise_por_id "$id" ;;
                /api/v1/resultado/*)
                    local id="${CAMINHO#/api/v1/resultado/}"
                    source "$BASE_MANIPULADORES/manipulador_analises.sh"
                    tratar_analise_por_id "$id" ;;
                *)
                    enviar_erro 404 "Rota nao encontrada" ;;
            esac ;;

        POST)
            case "$CAMINHO" in
                /api/v1/analisar | /api/analisar)
                    source "$BASE_MANIPULADORES/manipulador_iniciar.sh"
                    tratar_iniciar ;;
                /api/v1/analisar/parar | /api/analisar/parar)
                    source "$BASE_MANIPULADORES/manipulador_parar.sh"
                    tratar_parar ;;
                /api/v1/analisar/arquivo)
                    source "$BASE_MANIPULADORES/manipulador_arquivo.sh"
                    tratar_analisar_arquivo ;;
                /api/v1/projetos | /api/projetos)
                    source "$BASE_MANIPULADORES/manipulador_projetos.sh"
                    tratar_criar_projeto ;;
                /api/v1/projetos/*/upload-zip | /api/projetos/*/upload-zip)
                    local caminho_base="$CAMINHO"
                    caminho_base="${caminho_base#/api/v1/projetos/}"
                    caminho_base="${caminho_base#/api/projetos/}"
                    local id="${caminho_base%%/upload-zip}"
                    source "$BASE_MANIPULADORES/manipulador_projetos.sh"
                    tratar_upload_zip_projeto "$id" ;;
                /api/v1/projetos/*/analisar | /api/projetos/*/analisar)
                    local caminho_base="$CAMINHO"
                    caminho_base="${caminho_base#/api/v1/projetos/}"
                    caminho_base="${caminho_base#/api/projetos/}"
                    local id="${caminho_base%%/analisar}"
                    source "$BASE_MANIPULADORES/manipulador_projetos.sh"
                    tratar_analisar_projeto "$id" ;;
                /api/v1/projetos/*/analisar/parar | /api/projetos/*/analisar/parar)
                    local caminho_base="$CAMINHO"
                    caminho_base="${caminho_base#/api/v1/projetos/}"
                    caminho_base="${caminho_base#/api/projetos/}"
                    local id="${caminho_base%%/analisar/parar}"
                    source "$BASE_MANIPULADORES/manipulador_projetos.sh"
                    tratar_parar_projeto "$id" ;;
                /api/v1/projetos/*/confirmar-analise | /api/projetos/*/confirmar-analise)
                    local caminho_base="$CAMINHO"
                    caminho_base="${caminho_base#/api/v1/projetos/}"
                    caminho_base="${caminho_base#/api/projetos/}"
                    local id="${caminho_base%%/confirmar-analise}"
                    source "$BASE_MANIPULADORES/manipulador_projetos.sh"
                    tratar_confirmar_analise "$id" ;;
                /api/v1/projetos/*/reanalisar-erros | /api/projetos/*/reanalisar-erros)
                    local caminho_base="$CAMINHO"
                    caminho_base="${caminho_base#/api/v1/projetos/}"
                    caminho_base="${caminho_base#/api/projetos/}"
                    local id="${caminho_base%%/reanalisar-erros}"
                    source "$BASE_MANIPULADORES/manipulador_projetos.sh"
                    tratar_reanalisar_erros "$id" ;;
                /api/v1/projetos/*/reanalisar-arquivo/* | /api/projetos/*/reanalisar-arquivo/*)
                    local caminho_base="$CAMINHO"
                    caminho_base="${caminho_base#/api/v1/projetos/}"
                    caminho_base="${caminho_base#/api/projetos/}"
                    local id_projeto="${caminho_base%%/reanalisar-arquivo/*}"
                    local id_arquivo="${caminho_base##*/reanalisar-arquivo/}"
                    source "$BASE_MANIPULADORES/manipulador_projetos.sh"
                    tratar_reanalisar_arquivo "$id_projeto" "$id_arquivo" ;;
                *)
                    enviar_erro 404 "Rota nao encontrada" ;;
            esac ;;

        PUT)
            case "$CAMINHO" in
                /api/v1/projetos/* | /api/projetos/*)
                    local caminho_base="$CAMINHO"
                    caminho_base="${caminho_base#/api/v1/projetos/}"
                    caminho_base="${caminho_base#/api/projetos/}"
                    local id="${caminho_base%%/*}"
                    source "$BASE_MANIPULADORES/manipulador_projetos.sh"
                    tratar_atualizar_projeto "$id" ;;
                *)
                    enviar_erro 404 "Rota nao encontrada" ;;
            esac ;;

        DELETE)
            case "$CAMINHO" in
                /api/v1/cache/limpar | /api/cache/limpar)
                    source "$BASE_MANIPULADORES/manipulador_projetos.sh"
                    tratar_limpar_cache ;;
                /api/v1/projetos/* | /api/projetos/*)
                    local caminho_base="$CAMINHO"
                    caminho_base="${caminho_base#/api/v1/projetos/}"
                    caminho_base="${caminho_base#/api/projetos/}"
                    local id="${caminho_base%%/*}"
                    source "$BASE_MANIPULADORES/manipulador_projetos.sh"
                    tratar_excluir_projeto "$id" ;;
                *)
                    enviar_erro 404 "Rota nao encontrada" ;;
            esac ;;

        *)
            enviar_erro 405 "Método não permitido" ;;
    esac
}

# ─── Execução ───
interpretar_requisicao 2>/dev/null
rotear 2>/dev/null
[ -n "${CORPO_FILE:-}" ] && [ -f "$CORPO_FILE" ] && rm -f "$CORPO_FILE"
exit 0
