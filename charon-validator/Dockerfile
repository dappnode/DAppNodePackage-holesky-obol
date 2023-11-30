ARG UPSTREAM_VERSION

FROM node:20-alpine as lodestar-build

WORKDIR /usr/app

RUN apk update && apk add --no-cache git g++ make python3 && rm -rf /var/cache/apk/*

RUN git clone https://github.com/ChainSafe/lodestar

ARG LODESTAR_VERSION

RUN cd ./lodestar && \
    git checkout ${LODESTAR_VERSION} && \
    yarn install --non-interactive --frozen-lockfile && \
    yarn build && \
    yarn install --non-interactive --frozen-lockfile --production

FROM obolnetwork/charon:${UPSTREAM_VERSION}

USER root

# Install NodeJS to run Lodestar
RUN apt-get update && \
    apt-get install -y curl && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/*

RUN curl -SLO https://deb.nodesource.com/nsolid_setup_deb.sh && \
    chmod 500 nsolid_setup_deb.sh && \
    ./nsolid_setup_deb.sh 20 && \
    apt-get install -y nodejs && \
    rm nsolid_setup_deb.sh

COPY --from=lodestar-build /usr/app/lodestar /opt/validator

RUN mkdir -p /opt/charon/.charon && chown -R charon:charon /opt/charon

COPY entrypoint.sh /entrypoint.sh

# To prevent the user from editing the CLUSTER_ID, we set it as an ARG
ARG CLUSTER_ID
ENV CLUSTER_ID=${CLUSTER_ID} CHARON_LOG_FORMAT=console NETWORK=holesky \ 
    VALIDATOR_SERVICE_BIN=/opt/validator/packages/cli/bin/lodestar VALIDATOR_METRICS_PORT=8008

ENTRYPOINT ["/entrypoint.sh"]