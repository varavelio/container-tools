# Stage 1: Temporary downloader using latest Alpine
FROM alpine:latest AS downloader

ARG TAILWIND_VERSION \
    TARGETARCH

RUN apk add --no-cache curl ca-certificates && \
    case "${TARGETARCH}" in \
      "amd64") ARCH="x64" ;; \
      "arm64") ARCH="arm64" ;; \
      *) echo "Unsupported target arch: ${TARGETARCH}" && exit 1 ;; \
    esac && \
    curl -fsSL "https://github.com/tailwindlabs/tailwindcss/releases/download/v${TAILWIND_VERSION}/tailwindcss-linux-${ARCH}" -o /tmp/tailwindcss && \
    chmod +x /tmp/tailwindcss

# Stage 2: Final scratch image
FROM scratch

ARG TAILWIND_VERSION

LABEL org.opencontainers.image.source="https://github.com/varavel/container-tools" \
      org.opencontainers.image.title="tailwindcss" \
      org.opencontainers.image.version="${TAILWIND_VERSION}"

COPY --from=downloader /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=downloader /tmp/tailwindcss /usr/local/bin/tailwindcss

ENTRYPOINT ["/usr/local/bin/tailwindcss"]
