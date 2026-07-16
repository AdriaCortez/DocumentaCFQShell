FROM alpine:latest

RUN apk add --no-cache bash socat sqlite jq curl lsof coreutils findutils unzip

WORKDIR /app
COPY . /app

RUN mkdir -p dados/.controle dados/projetos

ENV OLLAMA_URL=http://ollama:11434/api/chat
ENV OLLAMA_GENERATE_URL=http://ollama:11434/api/generate
ENV API_PORTA=8080
ENV API_HOST=0.0.0.0
ENV MODO_SILENCIOSO=true

HEALTHCHECK --interval=10s --timeout=5s --start-period=5s --retries=3 \
    CMD curl -sf http://localhost:8080/api/v1/status || exit 1

EXPOSE 8080

CMD ["bash", "src/api/servidor.sh"]
