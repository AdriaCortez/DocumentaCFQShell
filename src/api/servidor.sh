#!/usr/bin/env bash
set -euo pipefail

# ─── Servidor HTTP da API de Análise ───

DIRETORIO_SCRIPT="$(cd "$(dirname "$(readlink -e "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")")" && cd ../.. && pwd)"
export DIRETORIO_SCRIPT_RAIZ="$DIRETORIO_SCRIPT"

source "$DIRETORIO_SCRIPT/config.sh"
source "$DIRETORIO_SCRIPT/src/util/validacao.sh"
source "$DIRETORIO_SCRIPT/src/controle/estado.sh"

inicializar_controle

export CAMINHO_ROTEADOR="$DIRETORIO_SCRIPT/src/api/roteador.sh"
LINK_ROTEADOR="/tmp/opencode-api-roteador.sh"
ln -sf "$CAMINHO_ROTEADOR" "$LINK_ROTEADOR"
trap 'rm -f "$LINK_ROTEADOR"' EXIT

if ! command -v socat &>/dev/null; then
    echo "Erro: socat não encontrado. Instale-o antes de executar." >&2
    exit 1
fi

EXISTENTE=$(lsof -ti "TCP:$PORTA_API" 2>/dev/null || true)
if [ -n "$EXISTENTE" ]; then
    echo "⚠ Porta $PORTA_API em uso. Matando processos: $EXISTENTE"
    kill "$EXISTENTE" 2>/dev/null || true
    sleep 1
fi

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  API de Analise de Codigo — v3                             ║"
echo "╠══════════════════════════════════════════════════════════════╣"
printf "║  Servidor:  http://%s:%s                              ║\n" "$HOST_API" "$PORTA_API"
echo "║  Banco:     $ARQUIVO_BANCO"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║  Endpoints:                                                 ║"
echo "║    GET  /api/v1/status              — Status da analise     ║"
echo "║    GET  /api/v1/progresso           — Progresso atual       ║"
echo "║    GET  /api/v1/analises            — Listar analises       ║"
echo "║    GET  /api/v1/analises/:id        — Analise por ID        ║"
echo "║    GET  /api/v1/analises/arquivo/:nome                      ║"
echo "║    GET  /api/v1/analises/ultima     — Ultima analise        ║"
echo "║    GET  /api/v1/estatisticas        — Estatisticas          ║"
echo "║    GET  /api/v1/fila                — Fila de arquivos      ║"
echo "║    GET  /api/v1/stream              — SSE (tempo real)      ║"
echo "║    GET  /api/v1/resultado/:id       — Resultado por ID      ║"
echo "║    POST /api/v1/analisar            — Iniciar analise       ║"
echo "║    POST /api/v1/analisar/parar      — Parar analise         ║"
echo "║    POST /api/v1/analisar/arquivo    — Analisar arquivo      ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║  Projetos:                                                  ║"
echo "║    GET    /api/v1/projetos          — Listar projetos       ║"
echo "║    POST   /api/v1/projetos          — Criar projeto         ║"
echo "║    GET    /api/v1/projetos/:id      — Detalhe do projeto    ║"
echo "║    PUT    /api/v1/projetos/:id      — Atualizar projeto     ║"
echo "║    DELETE /api/v1/projetos/:id      — Excluir projeto       ║"
echo "║    POST   /api/v1/projetos/:id/upload-zip — Upload ZIP      ║"
echo "║    POST   /api/v1/projetos/:id/analisar   — Analisar projeto║"
echo "║    GET    /api/v1/projetos/:id/progresso  — Progresso       ║"
echo "║    POST   /api/v1/projetos/:id/analisar/parar — Parar       ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "Pressione Ctrl+C para parar o servidor"
echo ""

exec socat "TCP-LISTEN:$PORTA_API,bind=$HOST_API,reuseaddr,fork,keepalive,keepcnt=9,keepidle=30,keepintvl=3" \
    SYSTEM:"timeout 9100 bash $LINK_ROTEADOR"
