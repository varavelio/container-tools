# Stage 1: Temporary downloader using latest Alpine
FROM alpine:latest AS downloader

ARG TASK_VERSION \
    TARGETARCH

RUN apk add --no-cache curl tar ca-certificates && \
    curl -fsSL "https://github.com/go-task/task/releases/download/v${TASK_VERSION}/task_linux_${TARGETARCH}.tar.gz" | \
    tar -xz -C /tmp task && \
    chmod +x /tmp/task

# Stage 2: Final scratch image
FROM scratch

ARG TASK_VERSION

LABEL org.opencontainers.image.source="https://github.com/varavel/container-tools" \
      org.opencontainers.image.title="task" \
      org.opencontainers.image.version="${TASK_VERSION}"

COPY --from=downloader /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=downloader /tmp/task /usr/local/bin/task

ENTRYPOINT ["/usr/local/bin/task"]
