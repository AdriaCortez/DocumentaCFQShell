#!/usr/bin/env bash
set -euo pipefail

# ─── Coleta de arquivos do diretório ───

coletar_arquivos() {
    local diretorio_alvo="${1:-.}"

    local find_args=("$diretorio_alvo")
    find_args+=(\()
    local primeiro=true
    for ext in "${EXTENSOES_VALIDAS[@]}"; do
        if $primeiro; then
            primeiro=false
        else
            find_args+=(-o)
        fi
        find_args+=(-name "*.$ext")
    done
    find_args+=(\))

    for dir in "${DIRETORIOS_EXCLUIDOS[@]}"; do
        find_args+=(-not -path "*/$dir/*")
    done

    find_args+=(-type f)

    declare -a arquivos_encontrados=()
    while IFS= read -r -d '' arquivo; do
        local relativo="${arquivo#./}"
        relativo="${relativo#"$diretorio_alvo/"}"
        [ -z "$relativo" ] && continue
        arquivos_encontrados+=("$relativo")
    done < <(find "${find_args[@]}" -print0 2>/dev/null)

    printf '%s\n' "${arquivos_encontrados[@]}"
}

filtar_arquivos_nao_analisados() {
    local arquivos=("$@")
    local pendentes=()
    local hashes_pendentes=()
    local pulados=0

    for arquivo in "${arquivos[@]}"; do
        local hash_arquivo
        hash_arquivo=$(calcular_hash "$arquivo")
        if [ -z "$hash_arquivo" ]; then
            continue
        fi

        if verificar_hash_existe "$hash_arquivo"; then
            exibir_cache "$arquivo"
            pulados=$((pulados + 1))
        else
            pendentes+=("$arquivo")
            hashes_pendentes+=("$hash_arquivo")
        fi
    done

    local resultado
    resultado=$(jq -n \
        --argjson pendentes "$(printf '%s\n' "${pendentes[@]}" | jq -R -s 'split("\n") | map(select(length > 0))')" \
        --argjson hashes "$(printf '%s\n' "${hashes_pendentes[@]}" | jq -R -s 'split("\n") | map(select(length > 0))')" \
        --argjson pulados "$pulados" \
        '{pendentes: $pendentes, hashes: $hashes, pulados: $pulados}')

    printf '%s' "$resultado"
}

obter_extensao_arquivo() {
    local caminho="$1"
    local ext="${caminho##*.}"
    if [ "$ext" = "$caminho" ]; then
        echo "txt"
    else
        echo "$ext"
    fi
}
