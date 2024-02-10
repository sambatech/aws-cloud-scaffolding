FROM quay.io/keycloak/keycloak:22.0.4 AS builder

# Configure a database vendor........
ENV KEYCLOAK_DATABASE_VENDOR=postgres
# Enable health and metrics support
ENV KEYCLOAK_ENABLE_STATISTICS=true
ENV KEYCLOAK_ENABLE_HEALTH_ENDPOINTS=true

WORKDIR /opt/keycloak

RUN /opt/keycloak/bin/kc.sh build

FROM quay.io/keycloak/keycloak:22.0.4

COPY --from=builder /opt/keycloak/ /opt/keycloak/

ENTRYPOINT ["/opt/keycloak/bin/kc.sh"]