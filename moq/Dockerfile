# Stage 1: Build the binary from source, pinned to the upstream release tag.
FROM golang:alpine AS builder

ARG MOQ_VERSION \
    TARGETARCH

RUN mkdir /src && cd /src && \
    go mod init build >/dev/null && \
    go get "github.com/matryer/moq@v${MOQ_VERSION}" >/dev/null && \
    CGO_ENABLED=0 GOOS=linux GOARCH="${TARGETARCH}" \
    go build -trimpath -ldflags "-s -w -X main.Version=${MOQ_VERSION}" \
    -o /out/moq github.com/matryer/moq

# Stage 2: Final scratch image with the binary only.
FROM scratch

ARG MOQ_VERSION

LABEL org.opencontainers.image.source="https://github.com/varavelio/container-tools" \
      org.opencontainers.image.title="moq" \
      org.opencontainers.image.version="${MOQ_VERSION}"

COPY --from=builder /out/moq /usr/local/bin/moq
