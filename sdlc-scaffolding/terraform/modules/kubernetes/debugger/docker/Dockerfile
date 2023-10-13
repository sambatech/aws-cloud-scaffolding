FROM debian:bookworm-slim

RUN apt-get update \
 && apt-get install -y curl jq unzip wget telnet dnsutils postgresql-client \
 && rm -rf /var/lib/apt/lists/*

ENTRYPOINT ["/bin/sh", "-c", "trap : TERM INT; sleep infinity & wait"]