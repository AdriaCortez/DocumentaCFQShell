#!/usr/bin/env bash
set -euo pipefail

# ─── Construção de prompts a partir de templates ───

carregar_template() {
    local tipo="$1"
    local caminho_template

    case "$tipo" in
        pagina|componente|servico)
            caminho_template="$DIRETORIO_TEMPLATES/$tipo.txt"
            ;;
        *)
            caminho_template="$DIRETORIO_TEMPLATES/padrao.txt"
            ;; 
    esac

    if [ ! -f "$caminho_template" ]; then
        printf 'Erro: template não encontrado: %s\n' "$caminho_template" >&2
        return 1
    fi

    cat "$caminho_template"
}

carregar_template_sistema() {
    local caminho_template="$DIRETORIO_TEMPLATES/sistema.txt"
    if [ ! -f "$caminho_template" ]; then
        printf 'Você é um analista de sistemas sênior especializado em documentação funcional.\n'
        return
    fi
    cat "$caminho_template"
}

construir_contexto_global() {
    local metadados="$1"

    local nome_projeto stack_arvore tech_classes tech_rotas

    nome_projeto=$(printf '%s' "$metadados" | jq -r '.nome_projeto // "Aplicação"')
    stack_arvore=$(construir_arvore_diretorios "$metadados")
    tech_classes=$(construir_lista_classes "$metadados")
    tech_rotas=$(construir_lista_rotas "$metadados")

    local stack_str=""
    local stack
    stack=$(printf '%s' "$metadados" | jq -r '.stack_tecnologica // [] | join(", ")')
    if [ -n "$stack" ] && [ "$stack" != "" ]; then
        stack_str="Tecnologias: $stack"
    fi

    cat <<EOF
=== CONTEXTO GLOBAL DO PROJETO ===
Nome: $nome_projeto
$stack_str

Estrutura de diretórios:
$stack_arvore

Rotas identificadas:
$tech_rotas

Classes:
$tech_classes
EOF
}

construir_arvore_diretorios() {
    local metadados="$1"
    local arvore
    arvore=$(printf '%s' "$metadados" | jq -r '.arvore_arquivos // [] | sort | .[]' 2>/dev/null)

    if [ -z "$arvore" ]; then
        echo "  (nenhum arquivo na árvore)"
        return
    fi

    while IFS= read -r linha; do
        echo "  $linha"
    done <<< "$arvore"
}

construir_lista_classes() {
    local metadados="$1"
    local classes
    classes=$(printf '%s' "$metadados" | jq -r '
        .classes // [] |
        map("  " + .nome + (if .estende then " → " + .estende else "" end) + " (" + .arquivo + ")") |
        .[]
    ' 2>/dev/null)

    if [ -z "$classes" ]; then
        echo "  (nenhuma classe identificada)"
        return
    fi

    printf '%s\n' "$classes"
}

construir_lista_rotas() {
    local metadados="$1"
    local rotas
    rotas=$(printf '%s' "$metadados" | jq -r '
        .rotas // [] |
        map("  " + .metodo + " " + .caminho + " (" + .arquivo + ")") |
        .[]
    ' 2>/dev/null)

    if [ -z "$rotas" ]; then
        echo "  (nenhuma rota identificada)"
        return
    fi

    printf '%s\n' "$rotas"
}

construir_referencias_cruzadas() {
    local dependencias_json="$1"
    local analises_concluidas_json="$2"

    local dependencias
    dependencias=$(printf '%s' "$dependencias_json" | jq -r '.[]' 2>/dev/null)

    if [ -z "$dependencias" ]; then
        return
    fi

    local referencias=""
    while IFS= read -r dep; do
        [ -z "$dep" ] && continue
        local arquivo_base="${dep##*/}"
        local resumo
        resumo=$(printf '%s' "$analises_concluidas_json" | jq -r --arg arquivo "$arquivo_base" '
            .[] | select(.arquivo | contains($arquivo)) | .resumo // ""
        ' 2>/dev/null | head -1)
        if [ -n "$resumo" ]; then
            referencias+=$(printf '  "%s" → %s\n' "$dep" "$resumo")
        fi
    done <<< "$dependencias"

    if [ -n "$referencias" ]; then
        printf '\n=== ARQUIVOS RELACIONADOS (já analisados) ===\n'
        printf '%s' "$referencias"
    fi
}

substituir_variaveis_template() {
    local template="$1"
    local variaveis_json="$2"

    local resultado="$template"

    resultado="${resultado//\{\{CONTEXTO_GLOBAL\}\}/$(printf '%s' "$variaveis_json" | jq -r '.contexto_global // ""')}"
    resultado="${resultado//\{\{CAMINHO_ARQUIVO\}\}/$(printf '%s' "$variaveis_json" | jq -r '.caminho_arquivo // ""')}"
    resultado="${resultado//\{\{NOME_PAGINA\}\}/$(printf '%s' "$variaveis_json" | jq -r '.nome_exibicao // ""')}"
    resultado="${resultado//\{\{NOME_COMPONENTE\}\}/$(printf '%s' "$variaveis_json" | jq -r '.nome_exibicao // ""')}"
    resultado="${resultado//\{\{NOME_SERVICO\}\}/$(printf '%s' "$variaveis_json" | jq -r '.nome_exibicao // ""')}"
    resultado="${resultado//\{\{NOME_ARQUIVO\}\}/$(printf '%s' "$variaveis_json" | jq -r '.nome_exibicao // ""')}"
    resultado="${resultado//\{\{TIPO_ARQUIVO\}\}/$(printf '%s' "$variaveis_json" | jq -r '.tipo_arquivo // ""')}"
    resultado="${resultado//\{\{LINGUAGEM\}\}/$(printf '%s' "$variaveis_json" | jq -r '.linguagem // ""')}"
    resultado="${resultado//\{\{IMPORTS\}\}/$(printf '%s' "$variaveis_json" | jq -r '.imports // ""')}"
    resultado="${resultado//\{\{EXPORTS\}\}/$(printf '%s' "$variaveis_json" | jq -r '.exports // ""')}"
    resultado="${resultado//\{\{REFERENCIAS_CRUZADAS\}\}/$(printf '%s' "$variaveis_json" | jq -r '.referencias_cruzadas // ""')}"
    resultado="${resultado//\{\{CONTEUDO_ARQUIVO\}\}/$(printf '%s' "$variaveis_json" | jq -r '.conteudo_arquivo // ""')}"
    resultado="${resultado//\{\{ANALISE_GLOBAL\}\}/$(printf '%s' "$variaveis_json" | jq -r '.analise_global // ""')}"

    printf '%s' "$resultado"
}

construir_prompt_global() {
    local metadados="$1"
    local arvore_arquivos="$2"
    local imports_exports="$3"
    local conteudo_principal="${4:-}"

    local nome_projeto contexto_global
    nome_projeto=$(printf '%s' "$metadados" | jq -r '.nome_projeto // "Projeto"')
    contexto_global=$(construir_contexto_global "$metadados")

    local template
    template=$(cat "$DIRETORIO_TEMPLATES/global.txt" 2>/dev/null || echo "")

    if [ -z "$template" ]; then
        printf '{"erro": "Template global.txt nao encontrado"}\n' >&2
        return 1
    fi

    local variaveis
    variaveis=$(jq -n \
        --arg contexto_global "$contexto_global" \
        --arg nome_projeto "$nome_projeto" \
        --arg arvore_arquivos "$arvore_arquivos" \
        --arg imports_exports "$imports_exports" \
        --arg conteudo_principal "$conteudo_principal" \
        '{contexto_global: $contexto_global, nome_projeto: $nome_projeto, arvore_arquivos: $arvore_arquivos, imports_exports: $imports_exports, conteudo_principal: $conteudo_principal}')

    local prompt_usuario
    prompt_usuario=$(substituir_variaveis_template_global "$template" "$variaveis")

    local prompt_sistema
    prompt_sistema=$(carregar_template_sistema)

    jq -n \
        --arg sistema "$prompt_sistema" \
        --arg usuario "$prompt_usuario" \
        '{sistema: $sistema, usuario: $usuario}'
}

substituir_variaveis_template_global() {
    local template="$1"
    local variaveis_json="$2"

    local resultado="$template"

    resultado="${resultado//\{\{CONTEXTO_GLOBAL\}\}/$(printf '%s' "$variaveis_json" | jq -r '.contexto_global // ""')}"
    resultado="${resultado//\{\{NOME_PROJETO\}\}/$(printf '%s' "$variaveis_json" | jq -r '.nome_projeto // ""')}"
    resultado="${resultado//\{\{ARVORE_ARQUIVOS\}\}/$(printf '%s' "$variaveis_json" | jq -r '.arvore_arquivos // ""')}"
    resultado="${resultado//\{\{IMPORTS_EXPORTS\}\}/$(printf '%s' "$variaveis_json" | jq -r '.imports_exports // ""')}"
    resultado="${resultado//\{\{CONTEUDO_PRINCIPAL\}\}/$(printf '%s' "$variaveis_json" | jq -r '.conteudo_principal // ""')}"

    printf '%s' "$resultado"
}

construir_prompt_completo() {
    local template_tipo="$1"
    local metadados="$2"
    local arquivo_dados="$3"
    local analises_concluidas="${4:-[]}"
    local analise_global="${5:-}"

    local contexto_global referencias
    contexto_global=$(construir_contexto_global "$metadados")

    local dependencias
    dependencias=$(printf '%s' "$arquivo_dados" | jq -r '.dependencias // []')
    referencias=$(construir_referencias_cruzadas "$dependencias" "$analises_concluidas")

    local caminho_arquivo linguagem tipo imports exports conteudo nome_exibicao
    caminho_arquivo=$(printf '%s' "$arquivo_dados" | jq -r '.caminho // ""')
    linguagem=$(printf '%s' "$arquivo_dados" | jq -r '.linguagem // ""')
    tipo=$(printf '%s' "$arquivo_dados" | jq -r '.tipo // "pagina"')
    imports=$(printf '%s' "$arquivo_dados" | jq -r '.imports // [] | join(", ")')
    exports=$(printf '%s' "$arquivo_dados" | jq -r '.exports // [] | join(", ")')
    conteudo=$(printf '%s' "$arquivo_dados" | jq -r '.conteudo // ""')
    nome_exibicao=$(basename "$caminho_arquivo" 2>/dev/null | sed 's/\.[^.]*$//')

    local template cru
    template=$(carregar_template "$template_tipo")

    local variaveis
    variaveis=$(jq -n \
        --arg contexto_global "$contexto_global" \
        --arg caminho_arquivo "$caminho_arquivo" \
        --arg nome_exibicao "$nome_exibicao" \
        --arg tipo_arquivo "$tipo" \
        --arg linguagem "$linguagem" \
        --arg imports "$imports" \
        --arg exports "$exports" \
        --arg referencias_cruzadas "${referencias:-}" \
        --arg conteudo_arquivo "$conteudo" \
        --arg analise_global "${analise_global:-}" \
        '{contexto_global: $contexto_global, caminho_arquivo: $caminho_arquivo, nome_exibicao: $nome_exibicao, tipo_arquivo: $tipo_arquivo, linguagem: $linguagem, imports: $imports, exports: $exports, referencias_cruzadas: $referencias_cruzadas, conteudo_arquivo: $conteudo_arquivo, analise_global: $analise_global}')

    local prompt_usuario
    prompt_usuario=$(substituir_variaveis_template "$template" "$variaveis")

    local prompt_sistema
    prompt_sistema=$(carregar_template_sistema)

    local resposta
    resposta=$(jq -n \
        --arg sistema "$prompt_sistema" \
        --arg usuario "$prompt_usuario" \
        '{sistema: $sistema, usuario: $usuario}')

    printf '%s' "$resposta"
}
