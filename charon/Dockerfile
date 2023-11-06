ARG UPSTREAM_VERSION

FROM obolnetwork/charon:${UPSTREAM_VERSION}

USER root

RUN apt install curl jq -y

RUN mkdir -p /opt/charon/.charon && chown -R charon:charon /opt/charon

COPY teku_security/ /opt/charon/teku/security/

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]