# Stage 1: Temporary downloader using latest Alpine
FROM alpine:latest AS downloader

ARG GOOSE_VERSION \
    TARGETARCH

RUN apk add --no-cache curl ca-certificates && \
    case "${TARGETARCH}" in \
      "amd64") ARCH="x86_64" ;; \
      "arm64") ARCH="arm64" ;; \
      *) echo "Unsupported target arch: ${TARGETARCH}" && exit 1 ;; \
    esac && \
    curl -fsSL "https://github.com/pressly/goose/releases/download/v${GOOSE_VERSION}/goose_linux_${ARCH}" -o /tmp/goose && \
    chmod +x /tmp/goose

# Stage 2: Final scratch image with the binary only. This image is meant for
# copying the binary out with `COPY --from`, not for running it.
FROM scratch

ARG GOOSE_VERSION

LABEL org.opencontainers.image.source="https://github.com/varavelio/container-tools" \
      org.opencontainers.image.title="goose" \
      org.opencontainers.image.version="${GOOSE_VERSION}"

COPY --from=downloader /tmp/goose /usr/local/bin/goose
