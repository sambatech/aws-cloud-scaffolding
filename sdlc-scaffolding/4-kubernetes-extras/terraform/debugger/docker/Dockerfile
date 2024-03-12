FROM debian:bookworm-slim

RUN apt update \
 && apt install -y iputils-ping dnsutils netcat-traditional telnet wget curl jq unzip postgresql-client \
 && rm -rf /var/lib/apt/lists/*

ENTRYPOINT ["/bin/sh", "-c", "trap : TERM INT; sleep infinity & wait"]