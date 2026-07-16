#!/usr/bin/env bash
set -euo pipefail

# ─── Configurações do Ollama ───
URL_OLLAMA="${OLLAMA_URL:-http://localhost:11434/api/chat}"
URL_OLLAMA_GENERATE="${OLLAMA_GENERATE_URL:-http://localhost:11434/api/generate}"
MODELO="gemma4:latest"

# ─── Configurações de retry e timeout ───
MAXIMO_RETENTATIVAS=3
INTERVALO_RETENTATIVA=2
TIMEOUT_REQUISICAO=300000
TEMPERATURA_LLM=0.3
TAMANHO_CONTEXTO=16384

# ─── Configurações da API ───
PORTA_API="${API_PORTA:-8080}"
HOST_API="${API_HOST:-0.0.0.0}"
VERSAO_API="v1"

# ─── Configurações de banco e persistência ───
DIRETORIO_RAIZ="$(cd "$(dirname "$(readlink -e "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")")" && pwd)"
DIRETORIO_DADOS="$DIRETORIO_RAIZ/dados"
ARQUIVO_BANCO="$DIRETORIO_DADOS/analises.db"
DIRETORIO_CONTROLE="$DIRETORIO_DADOS/.controle"
DIRETORIO_TEMPLATES="$DIRETORIO_RAIZ/templates"
DIRETORIO_PROJETOS="$DIRETORIO_DADOS/projetos"

# ─── Configurações de projetos ───
TAMANHO_MAX_ZIP_MB="${TAMANHO_MAX_ZIP_MB:-150}"
TAMANHO_MAX_ZIP_BYTES=$((TAMANHO_MAX_ZIP_MB * 1024 * 1024))
TAMANHO_MAX_ARQUIVO_MB="${TAMANHO_MAX_ARQUIVO_MB:-100}"
TAMANHO_MAX_ARQUIVO_BYTES=$((TAMANHO_MAX_ARQUIVO_MB * 1024 * 1024))
MAX_ARQUIVOS_PROJETO="${MAX_ARQUIVOS_PROJETO:-1000}"

# ─── Arquivos de controle ───
ARQUIVO_PID="$DIRETORIO_CONTROLE/analise.pid"
ARQUIVO_STATUS="$DIRETORIO_CONTROLE/analise.status"
ARQUIVO_PROGRESSO="$DIRETORIO_CONTROLE/analise.progresso"
ARQUIVO_EVENTOS="$DIRETORIO_CONTROLE/analise.events"
ARQUIVO_FILA="$DIRETORIO_CONTROLE/analise.fila"
ARQUIVO_LOG="$DIRETORIO_CONTROLE/analise.log"
ARQUIVO_PROJETO_ATUAL="$DIRETORIO_CONTROLE/projeto_atual.id"

# ─── Extensões válidas para análise ───
EXTENSOES_CODIGO=("js" "jsx" "ts" "tsx" "py" "java" "go" "rs" "rb" "php" "c" "cpp" "h" "cs" "swift" "kt" "groovy" "vue" "svelte" "graphql" "gql" "sql" "prisma")
EXTENSOES_CONFIGURACAO=("json" "yaml" "yml" "xml" "env" "toml")
EXTENSOES_ESTILO=("css" "scss" "less" "styl" "html" "htm")
EXTENSOES_VALIDAS=("${EXTENSOES_CODIGO[@]}" "${EXTENSOES_CONFIGURACAO[@]}" "${EXTENSOES_ESTILO[@]}")

# ─── Diretórios ignorados ───
DIRETORIOS_EXCLUIDOS=("node_modules" ".git" "dist" "build" ".next" ".nuxt" ".turbo" ".react-router" ".github" ".circleci" ".storybook" ".husky" "vendor" "venv" ".venv" "__pycache__" ".cache" ".parcel-cache" "coverage" "storybook-static" ".idea" ".vscode" ".terraform" "__mocks__" "__tests__" "test" "tests")

# ─── Arquivos ignorados por nome exato ───
ARQUIVOS_EXCLUIDOS_EXATOS=(".gitignore" ".dockerignore" ".editorconfig" ".nvmrc" ".npmrc" ".yarnrc" "nodemon.json" ".htaccess" "Dockerfile" "Vagrantfile" "nginx.conf" ".env" ".env.local" ".env.development" ".env.production" ".env.test" ".env.example" ".env.staging" ".env.qa" ".env.uat" "react-router.config.ts" "app.config.ts" "next.config.js" "next.config.mjs" "vite.config.ts" "vitest.config.ts" "tailwind.config.js" "tailwind.config.ts" "postcss.config.js" "postcss.config.ts" "eslint.config.js" "eslint.config.ts" "eslint.config.mjs" "compose.yaml" "compose.yml" "Jenkinsfile" "vercel.json" "firebase.json" "turbo.json" "nx.json" "lerna.json" "manifest.json" "robots.txt" ".ruby-version" ".python-version" ".node-version" ".tool-versions" ".gitattributes" ".npmignore")

# ─── Arquivos ignorados por prefixo ───
ARQUIVOS_EXCLUIDOS_PREFIXO=(".env." "docker-compose" "docker-compose." "compose." "codegen." "sitemap.")

# ─── Arquivos ignorados por padrão ───
ARQUIVOS_EXCLUIDOS_PADROES=("vite.config.*" "webpack.config.*" "rollup.config.*" "tsconfig.*" "jsconfig.*" "babel.config.*" ".babelrc" ".eslintrc.*" ".prettierrc.*" "jest.config.*" "tailwind.config.*" "next.config.*" "nuxt.config.*" "postcss.config.*" "eslint.config.*" "*.test.*" "*.spec.*" "*.stories.*" "*.d.ts" "*.d.tsx" "*.d.jsx" "*.config.js" "*.config.ts" "*.config.mjs" "*.config.cjs" ".github/workflows/*.yml" ".github/workflows/*.yaml" ".gitlab-ci.*" "azure-pipelines.*" "bitbucket-pipelines.*" ".circleci/config.*" "appveyor.*" ".travis.*" "serverless.*" "netlify.*" ".firebaserc" "cloudformation.*" "sam.*" "heroku.*" "amplify.*" "playwright.config.*" "cypress.config.*" "karma.conf.*" ".nycrc" "nyc.config.*" ".graphqlrc.*" "graphql.config.*" "esbuild.*" "swc.config.*" ".swcrc" "astro.config.*" "remix.config.*" "turbopack.config.*" "stylelint.config.*" ".stylelintrc*" "commitlint.config.*" ".commitlintrc*" "husky.config.*" ".huskyrc*" "lint-staged.config.*" ".lintstagedrc*" "markdownlint.*" ".markdownlintrc*" ".storybook/main.*" ".storybook/preview.*" "rush.json" "pnpm-workspace.*" ".browserslistrc" "browserslist" ".flowconfig" ".watchmanconfig" ".tern-project" "humans.txt")

# ─── Arquivos de manifesto/lock ───
ARQUIVOS_MANIFESTO=("package.json" "package-lock.json" "yarn.lock" "pnpm-lock.yaml" "composer.json" "composer.lock" "Gemfile" "Gemfile.lock" "requirements.txt" "Pipfile" "Pipfile.lock" "pyproject.toml" "Cargo.toml" "Cargo.lock" "go.mod" "go.sum" "pom.xml" "build.gradle" "build.gradle.kts" "settings.gradle" "Podfile" "Podfile.lock")

# ─── Outros arquivos ignorados ───
ARQUIVOS_DOCUMENTACAO=("README" "README.md" "README.txt" "LICENSE" "LICENSE.md" "CHANGELOG" "CHANGELOG.md" "CONTRIBUTING" "CONTRIBUTING.md" "Makefile" "Procfile" "app.json" ".gitkeep" "GEMINI.md" "documentation.txt")

# ─── Modo silencioso (quando usado como serviço) ───
MODO_SILENCIOSO="${MODO_SILENCIOSO:-false}"
