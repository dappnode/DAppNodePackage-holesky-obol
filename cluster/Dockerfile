ARG CHARON_VERSION
FROM obolnetwork/charon:${CHARON_VERSION}

ARG CLUSTER_ID
ARG VALIDATOR_CLIENT_VERSION

USER root

RUN apt-get update && \
    apt-get --yes --no-install-recommends install curl jq zip xz-utils inotify-tools supervisor && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/*

RUN mkdir -p /opt/validator/bin /usr/local/bin/scripts/charon /usr/local/bin/scripts/lodestar && \
    curl -L https://github.com/ChainSafe/lodestar/releases/download/${VALIDATOR_CLIENT_VERSION}/lodestar-${VALIDATOR_CLIENT_VERSION}-linux-amd64.tar.gz | tar -xz -C /opt/validator/bin && \
    chmod +x /opt/validator/bin/lodestar

COPY scripts /usr/local/bin/scripts
COPY supervisord.conf /etc/supervisord.conf

# To prevent the user from editing the CLUSTER_ID, we set it as an ARG
ENV CLUSTER_ID=${CLUSTER_ID} \
    CHARON_LOG_FORMAT=console \
    NETWORK=holesky \ 
    VALIDATOR_SERVICE_BIN=/opt/validator/bin/lodestar \
    VALIDATOR_DATA_DIR=/opt/validator/data \
    VALIDATOR_METRICS_PORT=8008 \
    CHARON_VALIDATOR_API_ADDRESS="0.0.0.0:3600" \
    CHARON_MONITORING_ADDRESS="0.0.0.0:3620" \
    CHARON_ROOT_DIR=/opt/charon/.charon \
    IMPORT_DIR=/import/ \
    SUPERVISOR_DIR=/supervisor

RUN mkdir -p ${CHARON_ROOT_DIR} ${VALIDATOR_DATA_DIR} ${IMPORT_DIR} ${SUPERVISOR_DIR} && \
    chown -R charon:charon /opt/charon && \
    chmod +x /usr/local/bin/scripts/**/*

# To import here the artifacts from file manager by default
WORKDIR /import

# Use supervisord to start services
CMD ["supervisord"]