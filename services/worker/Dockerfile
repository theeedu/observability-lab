# syntax=docker/dockerfile:1
# --------------------------------------------------------------------------- #
# Worker (Go) — build multi-stage, binário estático, imagem final mínima
# --------------------------------------------------------------------------- #
FROM golang:1.23-alpine AS build
WORKDIR /src

# Cache de dependências
COPY go.mod go.sum ./
RUN go mod download

COPY main.go .
# Binário estático (CGO desligado), com flags de tamanho
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /out/worker .

# --------------------------------------------------------------------------- #
FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /out/worker /worker
USER nonroot:nonroot
EXPOSE 9100
ENTRYPOINT ["/worker"]
