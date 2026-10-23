# Stage 1: Temporary downloader using latest Alpine
FROM alpine:latest AS downloader

ARG MOQ_VERSION \
    TARGETARCH

RUN apk add --no-cache curl tar ca-certificates && \
    case "${TARGETARCH}" in \
      "amd64") ARCH="x86_64" ;; \
      "arm64") ARCH="arm64" ;; \
      *) echo "Unsupported target arch: ${TARGETARCH}" && exit 1 ;; \
    esac && \
    curl -fsSL "https://github.com/matryer/moq/releases/download/v${MOQ_VERSION}/moq_Linux_${ARCH}.tar.gz" | \
    tar -xz -C /tmp moq && \
    chmod +x /tmp/moq

# Stage 2: Final scratch image with the binary only.
FROM scratch

ARG MOQ_VERSION

LABEL org.opencontainers.image.source="https://github.com/varavelio/container-tools" \
      org.opencontainers.image.title="moq" \
      org.opencontainers.image.version="${MOQ_VERSION}"

COPY --from=downloader /tmp/moq /usr/local/bin/moq
