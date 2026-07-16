#!/usr/bin/env bash
set -euo pipefail

# ─── Classificação de arquivos ───
# Retorna: "negocio", "framework", "configuracao" ou "biblioteca"

classificar_arquivo() {
    local caminho="$1"
    local nome_base
    nome_base=$(basename "$caminho")

    for diretorio in "${DIRETORIOS_EXCLUIDOS[@]}"; do
        if [[ "$caminho" == *"/$diretorio/"* ]] || [[ "$caminho" == "$diretorio/"* ]]; then
            echo "framework"
            return
        fi
    done

    for excluido in "${ARQUIVOS_EXCLUIDOS_EXATOS[@]}"; do
        if [ "$nome_base" = "$excluido" ]; then
            echo "configuracao"
            return
        fi
    done

    for prefixo in "${ARQUIVOS_EXCLUIDOS_PREFIXO[@]}"; do
        if [[ "$nome_base" == ${prefixo}* ]]; then
            echo "configuracao"
            return
        fi
    done

    for padrao in "${ARQUIVOS_EXCLUIDOS_PADROES[@]}"; do
        if [[ "$nome_base" == ${padrao} ]]; then
            echo "configuracao"
            return
        fi
    done

    for manifesto in "${ARQUIVOS_MANIFESTO[@]}"; do
        if [ "$nome_base" = "$manifesto" ]; then
            echo "biblioteca"
            return
        fi
    done

    for doc in "${ARQUIVOS_DOCUMENTACAO[@]}"; do
        if [ "$nome_base" = "$doc" ]; then
            echo "configuracao"
            return
        fi
    done

    echo "negocio"
}

classificar_tipo_arquivo() {
    local caminho="$1"
    local normalizado="${caminho//\\//}"
    local nome_base
    nome_base=$(basename "$caminho")

    if [[ "$normalizado" == *"/pages/"* ]] || [[ "$normalizado" == *"/page/"* ]] || \
       [[ "$normalizado" =~ /[A-Z][a-zA-Z]*Page\.(tsx|jsx|ts|js)$ ]] || \
       [[ "$normalizado" == *Page.tsx ]] || [[ "$normalizado" == *Page.jsx ]]; then
        echo "pagina"
        return
    fi

    if [[ "$normalizado" == *"/components/"* ]] || [[ "$normalizado" == *"/component/"* ]]; then
        echo "componente"
        return
    fi

    if [[ "$normalizado" == *"/services/"* ]] || [[ "$normalizado" == *"/service/"* ]]; then
        echo "servico"
        return
    fi

    if [[ "$normalizado" == *"/hooks/"* ]] || [[ "$normalizado" == *"/hook/"* ]] || \
       [[ "$nome_base" =~ ^use[A-Z] ]]; then
        echo "hook"
        return
    fi

    if [[ "$normalizado" == *"/stores/"* ]] || [[ "$normalizado" == *"/store/"* ]] || \
       [[ "$normalizado" == *"/contexts/"* ]] || [[ "$normalizado" == *"/context/"* ]]; then
        echo "store"
        return
    fi

    if [[ "$normalizado" == *"/layouts/"* ]] || [[ "$normalizado" == *"/layout/"* ]]; then
        echo "layout"
        return
    fi

    if [[ "$normalizado" == *"/middlewares/"* ]] || [[ "$normalizado" == *"/middleware/"* ]]; then
        echo "middleware"
        return
    fi

    if [[ "$normalizado" == *"/utils/"* ]] || [[ "$normalizado" == *"/helpers/"* ]] || \
       [[ "$normalizado" == *"/util/"* ]] || [[ "$normalizado" == *"/lib/"* ]] || \
       [[ "$normalizado" == *"/alertas/"* ]]; then
        echo "util"
        return
    fi

    if [[ "$normalizado" == *"/api/"* ]] || [[ "$normalizado" == *"/graphql/"* ]]; then
        echo "api"
        return
    fi

    if [[ "$normalizado" == *"/models/"* ]] || [[ "$normalizado" == *"/model/"* ]] || \
       [[ "$normalizado" == *"/schemas/"* ]] || [[ "$normalizado" == *"/schema/"* ]] || \
       [[ "$normalizado" == *"/entities/"* ]]; then
        echo "modelo"
        return
    fi

    if [[ "$normalizado" == *"/repositories/"* ]] || [[ "$normalizado" == *"/repository/"* ]] || \
       [[ "$normalizado" == *"/daos/"* ]] || [[ "$normalizado" == *"/dao/"* ]]; then
        echo "repositorio"
        return
    fi

    if [[ "$normalizado" == *"/dtos/"* ]] || [[ "$normalizado" == *"/dto/"* ]] || \
       [[ "$normalizado" == *"/serializers/"* ]]; then
        echo "dto"
        return
    fi

    if [[ "$normalizado" == *"/validators/"* ]] || [[ "$normalizado" == *"/validations/"* ]] || \
       [[ "$normalizado" == *"/validation/"* ]]; then
        echo "validacao"
        return
    fi

    if [[ "$normalizado" == *"/config/"* ]] || [[ "$normalizado" == *"/configs/"* ]] || \
       [[ "$normalizado" == *"/env/"* ]]; then
        echo "config"
        return
    fi

    if [[ "$normalizado" == *"/__tests__/"* ]] || [[ "$normalizado" == *"/tests/"* ]] || \
       [[ "$normalizado" == *"/test/"* ]] || [[ "$nome_base" =~ \.test\. ]] || [[ "$nome_base" =~ \.spec\. ]]; then
        echo "teste"
        return
    fi

    if [[ "$normalizado" == *"/controllers/"* ]] || [[ "$normalizado" == *"/controller/"* ]]; then
        echo "controller"
        return
    fi

    if [[ "$normalizado" == *"/routes/"* ]] || [[ "$normalizado" == *"/route/"* ]] || \
       [[ "$normalizado" == *"/routers/"* ]] || [[ "$normalizado" == *"/router/"* ]]; then
        echo "rota"
        return
    fi

    if [[ "$normalizado" == *"/styles/"* ]] || [[ "$normalizado" == *"/style/"* ]] || \
       [[ "$normalizado" == *"/css/"* ]] || [[ "$normalizado" == *"/scss/"* ]]; then
        echo "estilo"
        return
    fi

    echo "padrao"
}

mapear_tipos_para_secoes() {
    local tipos_str="$1"
    local resultado=""

    local IFS_antigo="$IFS"
    IFS=','
    local -a tipos=()
    for tipo in $tipos_str; do
        tipo=$(printf '%s' "$tipo" | xargs)
        tipos+=("$tipo")
    done
    IFS="$IFS_antigo"

    for tipo in "${tipos[@]}"; do
        case "$tipo" in
            pagina|componente|layout)
                resultado+="Estrutura da Interface"$'\n'
                resultado+="Fluxos Principais"$'\n'
                resultado+="Métricas"$'\n'
                resultado+="Inventário de Arquivos Relevantes"$'\n'
                ;;
            servico)
                resultado+="Estrutura da API"$'\n'
                resultado+="Dependências entre Módulos"$'\n'
                resultado+="Fluxos Principais"$'\n'
                resultado+="Métricas"$'\n'
                resultado+="Inventário de Arquivos Relevantes"$'\n'
                ;;
            controller)
                resultado+="Estrutura da API"$'\n'
                resultado+="Endpoints Reais da API"$'\n'
                resultado+="Fluxos Principais"$'\n'
                resultado+="Métricas"$'\n'
                resultado+="Inventário de Arquivos Relevantes"$'\n'
                ;;
            rota)
                resultado+="Estrutura da Interface"$'\n'
                resultado+="Fluxo de Navegação"$'\n'
                resultado+="Fluxos Principais"$'\n'
                resultado+="Endpoints Reais da API"$'\n'
                resultado+="Inventário de Arquivos Relevantes"$'\n'
                ;;
            repositorio)
                resultado+="Estrutura da API"$'\n'
                resultado+="Persistência"$'\n'
                resultado+="Dependências entre Módulos"$'\n'
                resultado+="Inventário de Arquivos Relevantes"$'\n'
                ;;
            middleware)
                resultado+="Estrutura da API"$'\n'
                resultado+="Dependências entre Módulos"$'\n'
                resultado+="Métricas"$'\n'
                ;;
            store|hook)
                resultado+="Estrutura da Interface"$'\n'
                resultado+="Dependências entre Módulos"$'\n'
                resultado+="Métricas"$'\n'
                ;;
            api)
                resultado+="Estrutura da API"$'\n'
                resultado+="Endpoints Reais da API"$'\n'
                resultado+="Dependências entre Módulos"$'\n'
                resultado+="Fluxos Principais"$'\n'
                resultado+="Métricas"$'\n'
                resultado+="Inventário de Arquivos Relevantes"$'\n'
                ;;
            modelo|schemas)
                resultado+="Modelo de Domínio"$'\n'
                resultado+="Persistência"$'\n'
                resultado+="Estrutura da API"$'\n'
                resultado+="Inventário de Arquivos Relevantes"$'\n'
                ;;
            validacao|dto)
                resultado+="Estrutura da API"$'\n'
                resultado+="Requisitos Funcionais"$'\n'
                resultado+="Inventário de Arquivos Relevantes"$'\n'
                ;;
            config)
                resultado+="Variáveis de Ambiente e Configurações"$'\n'
                resultado+="Tecnologias Identificadas"$'\n'
                resultado+="Padrões e Convenções Observadas"$'\n'
                ;;
            teste)
                resultado+="Testabilidade"$'\n'
                resultado+="Métricas"$'\n'
                ;;
            padrao|util|estilo)
                resultado+="Métricas"$'\n'
                resultado+="Padrões e Convenções Observadas"$'\n'
                resultado+="Inventário de Arquivos Relevantes"$'\n'
                ;;
            *)
                resultado+="Métricas"$'\n'
                resultado+="Inventário de Arquivos Relevantes"$'\n'
                resultado+="Padrões e Convenções Observadas"$'\n'
                ;;
        esac
    done

    printf '%s' "$resultado" | sort -u
}

classificar_lote() {
    local arquivos=("$@")
    local arquivos_negocio=()
    local arquivos_ignorados=()
    local motivos_ignorados=()
    local cont_framework=0
    local cont_configuracao=0
    local cont_biblioteca=0

    for arquivo in "${arquivos[@]}"; do
        local classificacao
        classificacao=$(classificar_arquivo "$arquivo")

        if [ "$classificacao" = "negocio" ]; then
            arquivos_negocio+=("$arquivo")
        else
            arquivos_ignorados+=("$arquivo")
            motivos_ignorados+=("$classificacao")
            case "$classificacao" in
                framework)     cont_framework=$((cont_framework + 1)) ;;
                configuracao)  cont_configuracao=$((cont_configuracao + 1)) ;;
                biblioteca)    cont_biblioteca=$((cont_biblioteca + 1)) ;;
            esac
        fi
    done

    local resultado
    resultado=$(jq -n \
        --argjson negocio "$(printf '%s\n' "${arquivos_negocio[@]}" | jq -R -s 'split("\n") | map(select(length > 0))')" \
        --argjson ignorados "$(printf '%s\n' "${arquivos_ignorados[@]}" | jq -R -s 'split("\n") | map(select(length > 0))')" \
        --argjson motivos "$(printf '%s\n' "${motivos_ignorados[@]}" | jq -R -s 'split("\n") | map(select(length > 0))')" \
        --argjson framework "$cont_framework" \
        --argjson configuracao "$cont_configuracao" \
        --argjson biblioteca "$cont_biblioteca" \
        '{
            negocio: $negocio,
            ignorados: {arquivos: $ignorados, motivos: $motivos},
            contagem: {framework: $framework, configuracao: $configuracao, biblioteca: $biblioteca}
        }')

    printf '%s' "$resultado"
}
