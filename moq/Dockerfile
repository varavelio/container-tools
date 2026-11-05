# Stage 1: Build the binary from source, pinned to the upstream release tag.
FROM golang:alpine AS builder

ARG MOQ_VERSION \
    TARGETARCH

# note: moq before 0.5.2 needs x/tools v0.24.0, which fails to compile with
# current Go (tokeninternal size assert), so those versions build with Go
# 1.23 instead. Drop the pin when they leave the build window.
RUN case "${MOQ_VERSION}" in \
      0.[0-4].*|0.5.0|0.5.1) export GOTOOLCHAIN=go1.23.12 ;; \
    esac && \
    mkdir /src && cd /src && \
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
