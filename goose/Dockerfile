# Stage 1: Temporary downloader using latest Alpine
FROM alpine:latest AS downloader

ARG GOOSE_VERSION \
    TARGETARCH

RUN apk add --no-cache curl ca-certificates && \
    curl -fsSL "https://github.com/pressly/goose/releases/download/v${GOOSE_VERSION}/goose_linux_${TARGETARCH}" -o /tmp/goose && \
    chmod +x /tmp/goose

# Stage 2: Final scratch image
FROM scratch

ARG GOOSE_VERSION

LABEL org.opencontainers.image.source="https://github.com/varavel/container-tools" \
      org.opencontainers.image.title="goose" \
      org.opencontainers.image.version="${GOOSE_VERSION}"

COPY --from=downloader /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=downloader /tmp/goose /usr/local/bin/goose

ENTRYPOINT ["/usr/local/bin/goose"]
