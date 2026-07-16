#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "$(readlink -e "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")")" && pwd)"

# ─── Forçar porta 8082 para compatibilidade com teste_callback_llm ───
export API_PORTA=8082
export OLLAMA_URL="${OLLAMA_URL:-http://localhost:11434/api/chat}"
export OLLAMA_GENERATE_URL="${OLLAMA_GENERATE_URL:-http://localhost:11434/api/generate}"

source "$DIR/config.sh"

echo "============================================================"
echo "  Inicializador — API de Analise de Codigo"
echo "============================================================"
echo ""

echo "→ Verificando Ollama em ${URL_OLLAMA%/*}..."
if ! curl -sf --max-time 5 "${URL_OLLAMA%/*}/tags" >/dev/null 2>&1; then
    echo "  ERRO: Ollama nao esta acessivel"
    echo "  Certifique-se de que o Ollama esta rodando (ex: ollama serve)"
    exit 1
fi
echo "  OK — Ollama acessivel"

echo "→ Verificando modelo $MODELO..."
if ! curl -sf --max-time 5 "${URL_OLLAMA%/*}/tags" | jq -e ".models[] | select(.name | contains(\"$MODELO\"))" >/dev/null 2>&1; then
    echo "  AVISO: Modelo $MODELO nao encontrado"
    echo "  Execute: ollama pull $MODELO"
    echo "  O servidor sera iniciado mesmo assim, mas analises falharao"
else
    echo "  OK — Modelo $MODELO disponivel"
fi

echo "→ Verificando porta $API_PORTA..."
if lsof -i "TCP:$API_PORTA" -t 2>/dev/null | head -1 >/dev/null; then
    echo "  AVISO: Porta $API_PORTA ja esta em uso"
    echo "  O servidor tentara libera-la automaticamente"
fi

echo ""
echo "→ Iniciando API na porta $API_PORTA..."
echo "  Endpoint: http://localhost:$API_PORTA/api/v1/status"
echo "  Pressione Ctrl+C para parar"
echo ""

exec bash "$DIR/src/api/servidor.sh"
