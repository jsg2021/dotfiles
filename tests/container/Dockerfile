# Disposable box for exercising ./install end to end.
# Build with --build-arg BASE=fedora:41 to test the dnf path.
ARG BASE=debian:bookworm-slim
FROM ${BASE}

# Only the tools the install script genuinely needs to be real.
# Everything that reaches the network or root is stubbed at run time.
RUN set -eux; \
    if command -v apt-get >/dev/null; then \
        apt-get update; \
        DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
            bash git zsh jq stow tar gzip ca-certificates procps file; \
        rm -rf /var/lib/apt/lists/*; \
    else \
        dnf -y install bash git zsh jq stow tar gzip procps-ng file; \
        dnf clean all; \
    fi

ENV HOME=/root
WORKDIR /root
COPY entrypoint.sh /usr/local/bin/run-scenario
RUN chmod +x /usr/local/bin/run-scenario
ENTRYPOINT ["/usr/local/bin/run-scenario"]
