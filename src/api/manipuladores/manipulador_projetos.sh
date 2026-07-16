#!/usr/bin/env bash
set -euo pipefail

tratar_criar_projeto() {
    if [ -z "$CORPO" ]; then
        enviar_erro 400 "Corpo da requisicao vazio"
        return
    fi

    if ! validar_json "$CORPO"; then
        enviar_erro 400 "JSON invalido no corpo da requisicao"
        return
    fi

    local nome descricao user_id
    nome=$(printf '%s' "$CORPO" | jq -r '.nome // ""')
    descricao=$(printf '%s' "$CORPO" | jq -r '.descricao // ""')
    user_id=$(printf '%s' "$CORPO" | jq -r '.user_id // 0')

    if [ -z "$user_id" ] || [ "$user_id" = "null" ]; then
        user_id="${CABECALHOS[x-user-id]:-0}"
    fi

    if [ -z "$nome" ]; then
        enviar_erro 400 "Nome do projeto e obrigatorio"
        return
    fi

    inicializar_banco
    local projeto_id
    projeto_id=$(criar_projeto "$nome" "$descricao" "$user_id")

    mkdir -p "$DIRETORIO_PROJETOS"

    local resposta
    resposta=$(jq -n \
        --argjson id "$projeto_id" \
        --arg nome "$nome" \
        --arg descricao "$descricao" \
        --arg status "criado" \
        '{id: $id, nome: $nome, descricao: $descricao, status: $status, mensagem: "Projeto criado com sucesso"}')

    enviar_json 201 "$resposta"
}

tratar_listar_projetos() {
    local user_id="${CABECALHOS[x-user-id]:-0}"
    inicializar_banco
    local resultado
    resultado=$(listar_projetos "$user_id")
    enviar_json 200 "$resultado"
}

tratar_obter_projeto() {
    local id="$1"
    local user_id="${CABECALHOS[x-user-id]:-0}"
    inicializar_banco

    local projeto
    projeto=$(obter_projeto_por_id_user "$id" "$user_id")

    if [ "$projeto" = "null" ]; then
        enviar_erro 404 "Projeto nao encontrado"
        return
    fi

    local arquivos
    arquivos=$(listar_arquivos_projeto "$id")

    local analises
    analises=$(obter_analises_projeto "$id")

    local stats
    stats=$(obter_estatisticas_projeto "$id")

    local tmp_projeto tmp_arquivos tmp_analises tmp_stats resposta
    tmp_projeto=$(mktemp)
    tmp_arquivos=$(mktemp)
    tmp_analises=$(mktemp)
    tmp_stats=$(mktemp)

    printf '%s' "$projeto" > "$tmp_projeto"
    printf '%s' "$arquivos" > "$tmp_arquivos"
    printf '%s' "$analises" > "$tmp_analises"
    printf '%s' "$stats" > "$tmp_stats"

    resposta=$(jq -n \
        --slurpfile projeto "$tmp_projeto" \
        --slurpfile arquivos "$tmp_arquivos" \
        --slurpfile analises "$tmp_analises" \
        --slurpfile estatisticas "$tmp_stats" \
        '{projeto: $projeto[0], arquivos: $arquivos[0], analises: $analises[0], estatisticas: $estatisticas[0]}')

    rm -f "$tmp_projeto" "$tmp_arquivos" "$tmp_analises" "$tmp_stats"

    enviar_json 200 "$resposta"
}

tratar_atualizar_projeto() {
    local id="$1"
    local user_id="${CABECALHOS[x-user-id]:-0}"
    inicializar_banco

    local projeto
    projeto=$(obter_projeto_por_id_user "$id" "$user_id")

    if [ "$projeto" = "null" ]; then
        enviar_erro 404 "Projeto nao encontrado"
        return
    fi

    if [ -z "$CORPO" ]; then
        enviar_erro 400 "Corpo da requisicao vazio"
        return
    fi

    if ! validar_json "$CORPO"; then
        enviar_erro 400 "JSON invalido no corpo da requisicao"
        return
    fi

    local nome descricao
    nome=$(printf '%s' "$CORPO" | jq -r '.nome // empty')
    descricao=$(printf '%s' "$CORPO" | jq -r '.descricao // empty')

    if [ -n "$nome" ]; then
        atualizar_projeto "$id" "nome" "$nome"
    fi

    if [ -n "$descricao" ]; then
        atualizar_projeto "$id" "descricao" "$descricao"
    fi

    local projeto_atualizado
    projeto_atualizado=$(obter_projeto_por_id "$id")

    enviar_json 200 "$projeto_atualizado"
}

tratar_excluir_projeto() {
    local id="$1"
    local user_id="${CABECALHOS[x-user-id]:-0}"
    inicializar_banco

    local projeto
    projeto=$(obter_projeto_por_id_user "$id" "$user_id")

    if [ "$projeto" = "null" ]; then
        enviar_erro 404 "Projeto nao encontrado"
        return
    fi

    local diretorio
    diretorio=$(printf '%s' "$projeto" | jq -r '.diretorio_upload // ""')

    excluir_projeto "$id"

    if [ -n "$diretorio" ] && [ -d "$diretorio" ]; then
        rm -rf "$diretorio"
    fi

    local resposta
    resposta=$(jq -n \
        --argjson id "$id" \
        '{mensagem: "Projeto excluido com sucesso", id: $id}')

    enviar_json 200 "$resposta"
}

tratar_upload_zip_projeto() {
    local id="$1"
    local user_id="${CABECALHOS[x-user-id]:-0}"
    inicializar_banco

    local projeto
    projeto=$(obter_projeto_por_id_user "$id" "$user_id")

    if [ "$projeto" = "null" ]; then
        enviar_erro 404 "Projeto nao encontrado"
        return
    fi

    if [ -z "$CORPO" ] && [ -z "${CORPO_FILE:-}" ]; then
        enviar_erro 400 "Corpo da requisicao vazio"
        return
    fi

    local corpo_fonte="$CORPO"
    if [ -n "${CORPO_FILE:-}" ] && [ -f "$CORPO_FILE" ]; then
        if ! jq empty "$CORPO_FILE" 2>/dev/null; then
            rm -f "$CORPO_FILE"
            enviar_erro 400 "JSON invalido no corpo da requisicao"
            return
        fi
        nome_arquivo=$(jq -r '.nome_arquivo // ""' "$CORPO_FILE")
    else
        if ! validar_json "$CORPO"; then
            enviar_erro 400 "JSON invalido no corpo da requisicao"
            return
        fi
        nome_arquivo=$(printf '%s' "$CORPO" | jq -r '.nome_arquivo // ""')
    fi

    if [ -z "$nome_arquivo" ]; then
        enviar_erro 400 "Nome do arquivo e obrigatorio"
        return
    fi

    local nome_projeto
    nome_projeto=$(printf '%s' "$projeto" | jq -r '.nome')

    local timestamp
    timestamp=$(date +%s)
    local dir_projeto="$DIRETORIO_PROJETOS/projeto_${id}_${timestamp}"
    mkdir -p "$dir_projeto"

    local zip_path="$dir_projeto/$nome_arquivo"

    if [ -n "${CORPO_FILE:-}" ] && [ -f "$CORPO_FILE" ]; then
        if ! jq -r '.conteudo_base64 // ""' "$CORPO_FILE" | base64 -d > "$zip_path" 2>/dev/null; then
            rm -rf "$dir_projeto"
            enviar_erro 400 "Falha ao decodificar base64 do ZIP"
            return
        fi
    else
        local conteudo_base64
        conteudo_base64=$(printf '%s' "$CORPO" | jq -r '.conteudo_base64 // ""')
        if [ -z "$conteudo_base64" ]; then
            enviar_erro 400 "Conteudo base64 do ZIP e obrigatorio"
            return
        fi
        printf '%s' "$conteudo_base64" | base64 -d > "$zip_path" 2>/dev/null
    fi

    if [ ! -f "$zip_path" ] || [ ! -s "$zip_path" ]; then
        rm -rf "$dir_projeto"
        enviar_erro 500 "Falha ao salvar arquivo ZIP"
        return
    fi

    local tamanho_zip
    tamanho_zip=$(stat -c%s "$zip_path" 2>/dev/null || echo 0)
    if [ "$tamanho_zip" -gt "$TAMANHO_MAX_ZIP_BYTES" ] 2>/dev/null; then
        rm -rf "$dir_projeto"
        enviar_erro 413 "Arquivo ZIP excede o limite maximo de ${TAMANHO_MAX_ZIP_MB}MB apos decodificacao"
        return
    fi

    if ! unzip -t "$zip_path" >/dev/null 2>&1; then
        rm -rf "$dir_projeto"
        enviar_erro 400 "Arquivo ZIP invalido ou corrompido"
        return
    fi

    local dir_extracao="$dir_projeto/conteudo"
    mkdir -p "$dir_extracao"

    if ! unzip -q -o "$zip_path" -d "$dir_extracao" 2>/dev/null; then
        rm -rf "$dir_projeto"
        enviar_erro 500 "Falha ao extrair arquivo ZIP"
        return
    fi

    local dir_fonte="$dir_extracao"
    local subdirs
    subdirs=$(find "$dir_extracao" -mindepth 1 -maxdepth 1 -type d | wc -l)
    local arquivos_raiz
    arquivos_raiz=$(find "$dir_extracao" -mindepth 1 -maxdepth 1 -type f | wc -l)

    if [ "$subdirs" -eq 1 ] && [ "$arquivos_raiz" -eq 0 ]; then
        dir_fonte=$(find "$dir_extracao" -mindepth 1 -maxdepth 1 -type d | head -1)
    fi

    local -a arquivos_coletados=()
    while IFS= read -r arquivo; do
        [ -z "$arquivo" ] && continue
        arquivos_coletados+=("$arquivo")
    done < <(coletar_arquivos "$dir_fonte")

    local total_arquivos=${#arquivos_coletados[@]}

    if [ "$total_arquivos" -eq 0 ]; then
        rm -rf "$dir_projeto"
        enviar_erro 400 "Nenhum arquivo de codigo encontrado no ZIP"
        return
    fi

    if [ "$total_arquivos" -gt "$MAX_ARQUIVOS_PROJETO" ]; then
        rm -rf "$dir_projeto"
        enviar_erro 400 "Projeto excede o limite de $MAX_ARQUIVOS_PROJETO arquivos (encontrados: $total_arquivos)"
        return
    fi

    local total_hits=0
    local total_misses=0
    local total_negocio=0
    local -a tipos_modificados=()
    local -a arquivos_modificados_json=()

    for arquivo in "${arquivos_coletados[@]}"; do
        local caminho_completo="$dir_fonte/$arquivo"
        local HASH=""
        if [ -f "$caminho_completo" ]; then
            HASH=$(calcular_hash "$caminho_completo" 2>/dev/null || echo "")
        fi
        local tipo
        tipo=$(classificar_tipo_arquivo "$arquivo")
        local classificacao
        classificacao=$(classificar_arquivo "$arquivo")

        if [ "$classificacao" != "negocio" ]; then
            continue
        fi

        total_negocio=$((total_negocio + 1))

        if [ -n "$HASH" ] && verificar_hash_existe "$HASH" "$user_id"; then
            total_hits=$((total_hits + 1))
        else
            total_misses=$((total_misses + 1))
            tipos_modificados+=("$tipo")
            arquivos_modificados_json+=("{\"caminho\":\"$arquivo\",\"tipo\":\"$tipo\"}")
        fi
    done

    local json_modificados="[]"
    if [ "$total_misses" -gt 0 ]; then
        json_modificados=$(printf '%s\n' "${arquivos_modificados_json[@]}" | jq -s '.')
    fi

    local secoes_afetadas=""
    if [ "$total_misses" -gt 0 ] && [ ${#tipos_modificados[@]} -gt 0 ]; then
        local tipos_unicos
        tipos_unicos=$(printf '%s\n' "${tipos_modificados[@]}" | sort -u | paste -sd ',' -)
        secoes_afetadas=$(mapear_tipos_para_secoes "$tipos_unicos")
    fi

    if [ "$total_negocio" -gt 0 ] && [ "$total_misses" -eq 0 ] && [ "$total_hits" -gt 0 ]; then
        sqlite3 -cmd ".output /dev/null" -cmd "PRAGMA journal_mode=WAL;" -cmd "PRAGMA busy_timeout=30000;" -cmd ".output stdout" "$ARQUIVO_BANCO" "DELETE FROM projetos_arquivos WHERE projeto_id=$id;"

        local projeto_global_origem="0"

        for arquivo in "${arquivos_coletados[@]}"; do
            local caminho_completo="$dir_fonte/$arquivo"
            local tamanho_arq=0
            if [ -f "$caminho_completo" ]; then
                tamanho_arq=$(stat -c%s "$caminho_completo" 2>/dev/null || echo 0)
            fi
            adicionar_arquivo_projeto "$id" "$arquivo" "$arquivo" "$tamanho_arq"

            local HASH
            HASH=$(calcular_hash "$caminho_completo" 2>/dev/null || echo "")
            if [ -n "$HASH" ]; then
                local cache_id
                cache_id=$(obter_analise_por_hash "$HASH" "$user_id" | jq -r '.id // 0')
                if [ "$cache_id" != "0" ]; then
                    executar_sqlite \
                        "INSERT INTO analises (nome_arquivo, conteudo_arquivo, interpretacao, data_hora, hash_arquivo, ignorado, motivo, projeto_id, user_id)
                         SELECT nome_arquivo, conteudo_arquivo, interpretacao, data_hora, hash_arquivo, ignorado, motivo, $id, user_id
                         FROM analises WHERE id=$cache_id;" 2>/dev/null || true
                    local novo_id
                    novo_id=$(executar_sqlite "SELECT last_insert_rowid();" 2>/dev/null || echo 0)
                    local arq_db_id
                    arq_db_id=$(executar_sqlite "SELECT id FROM projetos_arquivos WHERE projeto_id=$id AND nome='$arquivo' ORDER BY id DESC LIMIT 1;" 2>/dev/null || echo 0)
                    atualizar_arquivo_projeto_status "$arq_db_id" "analisado" "$novo_id"

                    if [ "$projeto_global_origem" = "0" ]; then
                        projeto_global_origem=$(executar_sqlite "SELECT projeto_id FROM analises WHERE id=$cache_id AND projeto_id IS NOT NULL LIMIT 1;" 2>/dev/null || echo "0")
                    fi
                fi
            fi
        done

        if [ "$projeto_global_origem" != "0" ]; then
            local global_origem
            global_origem=$(obter_analise_global_projeto "$projeto_global_origem" | jq -r '.interpretacao // ""')
            if [ -n "$global_origem" ] && [ "$global_origem" != "null" ]; then
                local arvore_global
                arvore_global=$(printf '%s\n' "${arquivos_coletados[@]}" | sort)
                salvar_analise_global "$id" "$global_origem" "$arvore_global" "$user_id"
            fi
        fi

        local arquivos_json
        arquivos_json=$(listar_arquivos_projeto "$id")
        atualizar_projeto "$id" "total_arquivos" "$total_arquivos"
        atualizar_projeto "$id" "arquivos_analisados" "$total_arquivos"
        atualizar_projeto "$id" "diretorio_upload" "$dir_fonte"
        atualizar_projeto_status "$id" "concluido"

        rm -f "$zip_path"

        local resposta
        resposta=$(jq -n \
            --argjson id "$id" \
            --arg status "concluido" \
            --argjson total_arquivos "$total_arquivos" \
            --arg diretorio "$dir_fonte" \
            --argjson arquivos "$arquivos_json" \
            --arg mensagem "Projeto ja foi analisado anteriormente. Todas as analises foram restauradas do cache." \
            '{mensagem: $mensagem, id: $id, status: $status, total_arquivos: $total_arquivos, diretorio: $diretorio, arquivos: $arquivos}')

        enviar_json 200 "$resposta"
        return
    fi

    sqlite3 -cmd ".output /dev/null" -cmd "PRAGMA journal_mode=WAL;" -cmd "PRAGMA busy_timeout=30000;" -cmd ".output stdout" "$ARQUIVO_BANCO" "DELETE FROM projetos_arquivos WHERE projeto_id=$id;"

    local i=0
    for arquivo in "${arquivos_coletados[@]}"; do
        local caminho_completo="$dir_fonte/$arquivo"
        local tamanho_arq=0
        if [ -f "$caminho_completo" ]; then
            tamanho_arq=$(stat -c%s "$caminho_completo" 2>/dev/null || echo 0)
        fi
        adicionar_arquivo_projeto "$id" "$arquivo" "$arquivo" "$tamanho_arq"
        i=$((i + 1))
    done

    atualizar_projeto "$id" "total_arquivos" "$total_arquivos"
    atualizar_projeto "$id" "diretorio_upload" "$dir_fonte"

    local status_resposta="pronto"
    if [ "$total_misses" -gt 0 ]; then
        status_resposta="aguardando_confirmacao"
        sqlite3 -cmd ".output /dev/null" -cmd "PRAGMA journal_mode=WAL;" -cmd "PRAGMA busy_timeout=30000;" -cmd ".output stdout" "$ARQUIVO_BANCO" \
            "UPDATE projetos SET status='aguardando_confirmacao' WHERE id=$id;" 2>/dev/null || true
    else
        atualizar_projeto_status "$id" "pronto"
    fi

    rm -f "$zip_path"

    local arquivos_json
    arquivos_json=$(listar_arquivos_projeto "$id")

    local sec_list="[]"
    if [ -n "$secoes_afetadas" ]; then
        sec_list=$(printf '%s' "$secoes_afetadas" | jq -R -s 'split("\n") | map(select(length > 0))' 2>/dev/null || echo "[]")
    fi

    local resposta
    resposta=$(jq -n \
        --argjson id "$id" \
        --arg status "$status_resposta" \
        --argjson total_arquivos "$total_arquivos" \
        --arg diretorio "$dir_fonte" \
        --argjson arquivos "$arquivos_json" \
        --argjson cache_hits "$total_hits" \
        --argjson cache_misses "$total_misses" \
        --argjson arquivos_modificados "$json_modificados" \
        --argjson secoes_afetadas "$sec_list" \
        '{mensagem: "ZIP extraido e arquivos vinculados ao projeto", id: $id, status: $status, total_arquivos: $total_arquivos, diretorio: $diretorio, arquivos: $arquivos, cache_info: {hits: $cache_hits, misses: $cache_misses, arquivos_modificados: $arquivos_modificados, secoes_afetadas: $secoes_afetadas}}')

    enviar_json 200 "$resposta"
}

tratar_confirmar_analise() {
    local id="$1"
    local user_id="${CABECALHOS[x-user-id]:-0}"
    inicializar_banco

    local projeto
    projeto=$(obter_projeto_por_id_user "$id" "$user_id")

    if [ "$projeto" = "null" ]; then
        enviar_erro 404 "Projeto nao encontrado"
        return
    fi

    local confirmacao
    confirmacao=$(printf '%s' "$CORPO" | jq -r '.confirmacao // "nao"' 2>/dev/null || echo "nao")

    if [ "$confirmacao" = "sim" ]; then
        local analise_global_antiga
        analise_global_antiga=$(obter_analise_global_projeto "$id")

        executar_sqlite "UPDATE projetos SET status='pronto' WHERE id=$id;" 2>/dev/null || true

        local resposta
        resposta=$(jq -n \
            --arg status "confirmado" \
            --arg mensagem "Analise confirmada. Inicie a analise pelo endpoint /analisar." \
            '{status: $status, mensagem: $mensagem}')
        enviar_json 200 "$resposta"
    else
        executar_sqlite "UPDATE projetos SET status='concluido_parcial' WHERE id=$id;" 2>/dev/null || true

        local resposta
        resposta=$(jq -n \
            --arg status "concluido_parcial" \
            --arg mensagem "ATENCAO: A analise global permanecera desatualizada! Faca upload novamente do arquivo para fazer a analise global." \
            --arg aviso "As analises individuais foram mantidas do cache. A analise global nao foi atualizada." \
            '{status: $status, mensagem: $mensagem, aviso: $aviso}')
        enviar_json 200 "$resposta"
    fi
}

tratar_analisar_projeto() {
    local id="$1"
    local user_id="${CABECALHOS[x-user-id]:-0}"
    inicializar_banco
    limpar_processos_travados

    local projeto
    projeto=$(obter_projeto_por_id_user "$id" "$user_id")

    if [ "$projeto" = "null" ]; then
        enviar_erro 404 "Projeto nao encontrado"
        return
    fi

    local status_projeto
    status_projeto=$(printf '%s' "$projeto" | jq -r '.status')

    if [ "$status_projeto" = "processando" ]; then
        enviar_erro 409 "Projeto ja esta sendo analisado"
        return
    fi

    local diretorio
    diretorio=$(printf '%s' "$projeto" | jq -r '.diretorio_upload // ""')

    if [ -z "$diretorio" ] || [ ! -d "$diretorio" ]; then
        enviar_erro 400 "Projeto nao possui arquivos. Faca upload de um ZIP primeiro."
        return
    fi

    local status_raw status_atual pid pid_valido
    status_raw=$(obter_status)
    IFS='|' read -r status_atual pid pid_valido <<< "$status_raw"

    if [ "$status_atual" = "executando" ]; then
        if [ "$pid_valido" = "true" ] && [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            enviar_erro 409 "Ja existe uma analise em execucao"
            return
        else
            definir_status "parado"
        fi
    fi

    local total_arquivos
    total_arquivos=$(printf '%s' "$projeto" | jq -r '.total_arquivos // 0')

    if [ "$total_arquivos" -eq 0 ]; then
        enviar_erro 400 "Projeto nao possui arquivos para analisar"
        return
    fi

    local data_hora mudou
    data_hora=$(date '+%Y-%m-%d %H:%M:%S')
    mudou=$(executar_sqlite \
        "UPDATE projetos SET status='processando', data_atualizacao='$data_hora' WHERE id=$id AND status != 'processando'; SELECT changes();" 2>/dev/null || echo 0)

    if [ "$mudou" -eq 0 ] 2>/dev/null; then
        enviar_erro 409 "Projeto ja esta sendo analisado (iniciado em outra requisicao simultanea)"
        return
    fi

    executar_sqlite "UPDATE projetos SET arquivos_analisados=0 WHERE id=$id;" 2>/dev/null || true

    local arquivos_json
    arquivos_json=$(listar_arquivos_projeto "$id")
    printf '%s' "$arquivos_json" > "$DIRETORIO_CONTROLE/projeto_${id}_arquivos.json"
    printf '%s' "$id" > "$ARQUIVO_PROJETO_ATUAL"

    inicializar_controle
    inicializar_eventos
    definir_status "executando"

    local diretorio_scripts
    diretorio_scripts="$DIRETORIO_RAIZ"

    setsid bash "$diretorio_scripts/src/analise/analisar_projeto.sh" "$id" "$diretorio" \
        >> "$ARQUIVO_LOG" 2>&1 </dev/null &
    local pid_novo=$!
    disown
    definir_pid "$pid_novo"

    local resposta
    resposta=$(jq -n \
        --arg status "iniciado" \
        --arg mensagem "Analise do projeto iniciada em background" \
        --argjson pid "$pid_novo" \
        --argjson projeto_id "$id" \
        '{status: $status, mensagem: $mensagem, pid: $pid, projeto_id: $projeto_id}')

    enviar_json 200 "$resposta"
}

tratar_progresso_projeto() {
    local id="$1"
    local user_id="${CABECALHOS[x-user-id]:-0}"
    inicializar_banco

    local projeto
    projeto=$(obter_projeto_por_id_user "$id" "$user_id")

    if [ "$projeto" = "null" ]; then
        enviar_erro 404 "Projeto nao encontrado"
        return
    fi

    local json_progresso
    json_progresso=$(obter_json_progresso)

    local stats
    stats=$(obter_estatisticas_projeto "$id")

    local status_projeto
    status_projeto=$(printf '%s' "$projeto" | jq -r '.status')

    local resposta
    resposta=$(jq -n \
        --arg status_projeto "$status_projeto" \
        --argjson progresso "$json_progresso" \
        --argjson estatisticas "$stats" \
        '{status_projeto: $status_projeto, progresso: $progresso, estatisticas: $estatisticas}')

    enviar_json 200 "$resposta"
}

tratar_parar_projeto() {
    local id="$1"
    local user_id="${CABECALHOS[x-user-id]:-0}"
    inicializar_banco

    local projeto
    projeto=$(obter_projeto_por_id_user "$id" "$user_id")

    if [ "$projeto" = "null" ]; then
        enviar_erro 404 "Projeto nao encontrado"
        return
    fi

    local status_raw status pid pid_valido
    status_raw=$(obter_status)
    IFS='|' read -r status pid pid_valido <<< "$status_raw"

    if [ "$status" != "executando" ]; then
        atualizar_projeto_status "$id" "parado"
        local resposta
        resposta=$(jq -n \
            --arg status "sem_analise" \
            --arg mensagem "Nenhuma analise em execucao" \
            '{status: $status, mensagem: $mensagem}')
        enviar_json 200 "$resposta"
        return
    fi

    definir_status "parando"

    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
        kill -TERM "$pid" 2>/dev/null || true
    fi

    atualizar_projeto_status "$id" "parado"
    escrever_evento "parada_solicitada" "$(jq -n --arg pid "$pid" '{pid: $pid}')"

    local resposta
    resposta=$(jq -n \
        --arg status "parando" \
        --arg mensagem "Solicitacao de parada enviada" \
        '{status: $status, mensagem: $mensagem}')

    enviar_json 200 "$resposta"
}

tratar_analise_global_projeto() {
    local id="$1"
    local user_id="${CABECALHOS[x-user-id]:-0}"
    inicializar_banco

    local projeto
    projeto=$(obter_projeto_por_id_user "$id" "$user_id")

    if [ "$projeto" = "null" ]; then
        enviar_erro 404 "Projeto nao encontrado"
        return
    fi

    local analise_global
    analise_global=$(obter_analise_global_projeto "$id")

    if [ "$analise_global" = "null" ]; then
        enviar_erro 404 "Analise global nao encontrada para este projeto"
        return
    fi

    enviar_json 200 "$analise_global"
}

tratar_reanalisar_erros() {
    local id="$1"
    local user_id="${CABECALHOS[x-user-id]:-0}"
    inicializar_banco
    limpar_processos_travados

    local projeto
    projeto=$(obter_projeto_por_id_user "$id" "$user_id")

    if [ "$projeto" = "null" ]; then
        enviar_erro 404 "Projeto nao encontrado"
        return
    fi

    local diretorio
    diretorio=$(printf '%s' "$projeto" | jq -r '.diretorio_upload // ""')

    if [ -z "$diretorio" ] || [ ! -d "$diretorio" ]; then
        enviar_erro 400 "Projeto nao possui arquivos para re-analisar"
        return
    fi

    local resetados
    resetados=$(sqlite3 -cmd ".output /dev/null" -cmd "PRAGMA journal_mode=WAL;" -cmd "PRAGMA busy_timeout=30000;" -cmd ".output stdout" "$ARQUIVO_BANCO" \
        "UPDATE projetos_arquivos SET status='pendente', analise_id=NULL WHERE projeto_id=$id AND (status='erro' OR status='analisando');
         SELECT changes();" 2>/dev/null || echo 0)

    if [ "$resetados" -eq 0 ] 2>/dev/null; then
        enviar_json 200 "$(jq -n --arg status "sem_erros" --arg mensagem "Nenhum arquivo com erro ou analisando encontrado" '{status: $status, mensagem: $mensagem}')"
        return
    fi

    local status_raw status_atual pid pid_valido
    status_raw=$(obter_status)
    IFS='|' read -r status_atual pid pid_valido <<< "$status_raw"

    if [ "$status_atual" = "executando" ]; then
        if [ "$pid_valido" = "true" ] && [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            enviar_erro 409 "Ja existe uma analise em execucao"
            return
        else
            definir_status "parado"
        fi
    fi

    local data_hora mudou
    data_hora=$(date '+%Y-%m-%d %H:%M:%S')
    mudou=$(executar_sqlite \
        "UPDATE projetos SET status='processando', data_atualizacao='$data_hora' WHERE id=$id AND status != 'processando'; SELECT changes();" 2>/dev/null || echo 0)

    if [ "$mudou" -eq 0 ] 2>/dev/null; then
        enviar_erro 409 "Projeto ja esta sendo analisado (iniciado em outra requisicao simultanea)"
        return
    fi

    executar_sqlite "UPDATE projetos SET arquivos_analisados=0 WHERE id=$id;" 2>/dev/null || true

    local arquivos_json
    arquivos_json=$(listar_arquivos_projeto "$id")
    printf '%s' "$arquivos_json" > "$DIRETORIO_CONTROLE/projeto_${id}_arquivos.json"
    printf '%s' "$id" > "$ARQUIVO_PROJETO_ATUAL"

    inicializar_controle
    inicializar_eventos
    definir_status "executando"

    local diretorio_scripts
    diretorio_scripts="$DIRETORIO_RAIZ"

    setsid bash "$diretorio_scripts/src/analise/analisar_projeto.sh" "$id" "$diretorio" \
        >> "$ARQUIVO_LOG" 2>&1 </dev/null &
    local pid_novo=$!
    disown
    definir_pid "$pid_novo"

    local resposta
    resposta=$(jq -n \
        --arg status "iniciado" \
        --arg mensagem "Re-analise iniciada" \
        --argjson pid "$pid_novo" \
        --argjson projeto_id "$id" \
        --argjson arquivos_reanalisados "$resetados" \
        '{status: $status, mensagem: $mensagem, pid: $pid, projeto_id: $projeto_id, arquivos_reanalisados: $arquivos_reanalisados}')

    enviar_json 200 "$resposta"
}

tratar_reanalisar_arquivo() {
    local projeto_id="$1"
    local arquivo_id="$2"
    local user_id="${CABECALHOS[x-user-id]:-0}"
    inicializar_banco
    limpar_processos_travados

    local projeto
    projeto=$(obter_projeto_por_id_user "$projeto_id" "$user_id")

    if [ "$projeto" = "null" ]; then
        enviar_erro 404 "Projeto nao encontrado"
        return
    fi

    local arquivo
    arquivo=$(sqlite3 -json -cmd ".output /dev/null" -cmd "PRAGMA journal_mode=WAL;" -cmd "PRAGMA busy_timeout=30000;" -cmd ".output stdout" "$ARQUIVO_BANCO" \
        "SELECT * FROM projetos_arquivos WHERE id=$arquivo_id AND projeto_id=$projeto_id;" \
        2>/dev/null | jq '.[0] // null' 2>/dev/null || echo "null")

    if [ "$arquivo" = "null" ]; then
        enviar_erro 404 "Arquivo nao encontrado no projeto"
        return
    fi

    local status_arquivo
    status_arquivo=$(printf '%s' "$arquivo" | jq -r '.status')

    if [ "$status_arquivo" != "erro" ] && [ "$status_arquivo" != "analisando" ]; then
        enviar_erro 400 "Arquivo nao esta com erro ou travado (status: $status_arquivo)"
        return
    fi

    sqlite3 -cmd ".output /dev/null" -cmd "PRAGMA journal_mode=WAL;" -cmd "PRAGMA busy_timeout=30000;" -cmd ".output stdout" "$ARQUIVO_BANCO" \
        "UPDATE projetos_arquivos SET status='pendente', analise_id=NULL WHERE id=$arquivo_id;" 2>/dev/null || true

    local diretorio
    diretorio=$(printf '%s' "$projeto" | jq -r '.diretorio_upload // ""')

    local status_raw status_atual pid pid_valido
    status_raw=$(obter_status)
    IFS='|' read -r status_atual pid pid_valido <<< "$status_raw"

    if [ "$status_atual" = "executando" ]; then
        if [ "$pid_valido" = "true" ] && [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            enviar_erro 409 "Ja existe uma analise em execucao"
            return
        else
            definir_status "parado"
        fi
    fi

    local data_hora mudou
    data_hora=$(date '+%Y-%m-%d %H:%M:%S')
    mudou=$(executar_sqlite \
        "UPDATE projetos SET status='processando', data_atualizacao='$data_hora' WHERE id=$projeto_id AND status != 'processando'; SELECT changes();" 2>/dev/null || echo 0)

    if [ "$mudou" -eq 0 ] 2>/dev/null; then
        enviar_erro 409 "Projeto ja esta sendo analisado (iniciado em outra requisicao simultanea)"
        return
    fi

    local arquivos_json
    arquivos_json=$(listar_arquivos_projeto "$projeto_id")
    printf '%s' "$arquivos_json" > "$DIRETORIO_CONTROLE/projeto_${projeto_id}_arquivos.json"
    printf '%s' "$projeto_id" > "$ARQUIVO_PROJETO_ATUAL"

    inicializar_controle
    inicializar_eventos
    definir_status "executando"

    local diretorio_scripts
    diretorio_scripts="$DIRETORIO_RAIZ"

    setsid bash "$diretorio_scripts/src/analise/analisar_projeto.sh" "$projeto_id" "$diretorio" \
        >> "$ARQUIVO_LOG" 2>&1 </dev/null &
    local pid_novo=$!
    disown
    definir_pid "$pid_novo"

    local nome_arquivo
    nome_arquivo=$(printf '%s' "$arquivo" | jq -r '.nome // "arquivo_desconhecido"')

    local resposta
    resposta=$(jq -n \
        --arg status "iniciado" \
        --arg mensagem "Re-analise do arquivo iniciada" \
        --argjson pid "$pid_novo" \
        --argjson projeto_id "$projeto_id" \
        --argjson arquivo_id "$arquivo_id" \
        --arg nome_arquivo "$nome_arquivo" \
        '{status: $status, mensagem: $mensagem, pid: $pid, projeto_id: $projeto_id, arquivo_id: $arquivo_id, nome_arquivo: $nome_arquivo}')

    enviar_json 200 "$resposta"
}

tratar_limpar_cache() {
    local user_id="${CABECALHOS[x-user-id]:-0}"
    inicializar_banco

    local total_antes total_depois removidos
    total_antes=$(executar_sqlite "SELECT count(*) FROM analises;" 2>/dev/null || echo 0)

    limpar_cache_antigo

    total_depois=$(executar_sqlite "SELECT count(*) FROM analises;" 2>/dev/null || echo 0)
    removidos=$((total_antes - total_depois))

    local resposta
    resposta=$(jq -n \
        --argjson removidos "$removidos" \
        --argjson total_antes "$total_antes" \
        --argjson total_depois "$total_depois" \
        '{mensagem: "Cache limpo com sucesso", registros_removidos: $removidos, total_antes: $total_antes, total_depois: $total_depois}')

    enviar_json 200 "$resposta"
}
