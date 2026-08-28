# Stage 1: Temporary downloader using latest Alpine
FROM alpine:latest AS downloader

ARG DPRINT_VERSION \
    TARGETARCH

RUN apk add --no-cache curl unzip ca-certificates && \
    case "${TARGETARCH}" in \
      "amd64") ARCH="x86_64" ;; \
      "arm64") ARCH="aarch64" ;; \
      *) echo "Unsupported target arch: ${TARGETARCH}" && exit 1 ;; \
    esac && \
    curl -fsSL "https://github.com/dprint/dprint/releases/download/${DPRINT_VERSION}/dprint-${ARCH}-unknown-linux-gnu.zip" -o /tmp/dprint-gnu.zip && \
    unzip -qjo /tmp/dprint-gnu.zip -d /tmp/gnu && \
    curl -fsSL "https://github.com/dprint/dprint/releases/download/${DPRINT_VERSION}/dprint-${ARCH}-unknown-linux-musl.zip" -o /tmp/dprint-musl.zip && \
    unzip -qjo /tmp/dprint-musl.zip -d /tmp/musl && \
    chmod +x /tmp/gnu/dprint /tmp/musl/dprint

# Stage 2: Final scratch image with both standalone binaries (the default
# glibc build and the musl one), so consumers pick whichever matches their
# base image.
FROM scratch

ARG DPRINT_VERSION

LABEL org.opencontainers.image.source="https://github.com/varavelio/container-tools" \
      org.opencontainers.image.title="dprint" \
      org.opencontainers.image.version="${DPRINT_VERSION}"

COPY --from=downloader /tmp/gnu/dprint /usr/local/bin/dprint
COPY --from=downloader /tmp/musl/dprint /usr/local/bin/dprint-musl
