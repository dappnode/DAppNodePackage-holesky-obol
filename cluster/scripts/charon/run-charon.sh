#!/bin/bash

#############
# VARIABLES #
#############
ERROR="[ ERROR | charon-manager ]"
INFO="[ INFO | charon-manager ]"

CREATE_ENR_FILE=${CHARON_ROOT_DIR}/create_enr.txt
ENR_PRIVATE_KEY_FILE=${CHARON_ROOT_DIR}/charon-enr-private-key
ENR_FILE=${CHARON_ROOT_DIR}/enr
DEFINITION_FILE_URL_FILE=${CHARON_ROOT_DIR}/definition_file_url.txt

CHARON_LOCK_FILE=${CHARON_ROOT_DIR}/cluster-lock.json

if [ -n "$DEFINITION_FILE_URL" ]; then
    echo "$DEFINITION_FILE_URL" >$DEFINITION_FILE_URL_FILE
fi

if [ "$ENABLE_MEV_BOOST" = true ]; then
    CHARON_EXTRA_OPTS="--builder-api $CHARON_EXTRA_OPTS"

    VALIDATOR_EXTRA_OPTS="--builder=true --builder.selection=builderonly $VALIDATOR_EXTRA_OPTS"
fi

export CHARON_P2P_EXTERNAL_HOSTNAME=${_DAPPNODE_GLOBAL_DOMAIN}

#############
# FUNCTIONS #
#############

function get_beacon_node_endpoint() {

    if [ -n "$CUSTOM_BEACON_NODE_URLS" ]; then
        export CHARON_BEACON_NODE_ENDPOINTS=$CUSTOM_BEACON_NODE_URLS
        echo "Using external beacon node endpoint: $CUSTOM_BEACON_NODE_URLS"
        return
    fi

    case "$_DAPPNODE_GLOBAL_CONSENSUS_CLIENT_HOLESKY" in
    "prysm-holesky.dnp.dappnode.eth")
        export CHARON_BEACON_NODE_ENDPOINTS="http://beacon-chain.prysm-holesky.dappnode:3500"
        ;;
    "teku-holesky.dnp.dappnode.eth")
        export CHARON_BEACON_NODE_ENDPOINTS="http://beacon-chain.teku-holesky.dappnode:3500"
        ;;
    "lighthouse-holesky.dnp.dappnode.eth")
        export CHARON_BEACON_NODE_ENDPOINTS="http://beacon-chain.lighthouse-holesky.dappnode:3500"
        ;;
    "nimbus-holesky.dnp.dappnode.eth")
        export CHARON_BEACON_NODE_ENDPOINTS="http://beacon-validator.nimbus-holesky.dappnode:4500"
        ;;
    "lodestar-holesky.dnp.dappnode.eth")
        export CHARON_BEACON_NODE_ENDPOINTS="http://beacon-chain.lodestar-holesky.dappnode:3500"
        ;;
    *)
        echo "${ERROR} Unknown value for _DAPPNODE_GLOBAL_CONSENSUS_CLIENT_HOLESKY: $_DAPPNODE_GLOBAL_CONSENSUS_CLIENT_HOLESKY"
        echo "${ERROR} Please set a full node for network ${NETWORK} in the Stakers tab or input a custom beacon node URL in this package config."
        ;;
    esac
}

# Get the ENR of the node or create it if it does not exist
function get_ENR() {
    # Check if ENR file exists and create it if it does not
    if [[ ! -f "$ENR_PRIVATE_KEY_FILE" ]]; then
        echo "${INFO} ENR does not exist, creating it..."
        if ! charon create enr --data-dir=${CHARON_ROOT_DIR} | tee ${CREATE_ENR_FILE}; then
            echo "${ERROR} Failed to create ENR."
            exit 1
        fi
    fi

    echo "${INFO} Storing ENR to file..."
    ENR=$(charon enr --data-dir=${CHARON_ROOT_DIR})
    echo "[INFO] ENR: ${ENR}"
    echo "${ENR}" >$ENR_FILE

    echo "${INFO} Publishing ENR to dappmanager..."
    post_ENR_to_dappmanager
}

# function to be post the ENR to dappmanager
function post_ENR_to_dappmanager() {
    # Post ENR to dappmanager
    curl --connect-timeout 5 \
        --max-time 10 \
        --silent \
        --retry 5 \
        --retry-delay 0 \
        --retry-max-time 40 \
        -X POST "http://my.dappnode/data-send?key=ENR%20Cluster%20${CLUSTER_ID}&data=${ENR}" ||
        {
            echo "[ERROR] failed to post ENR to dappmanager"
        }
}

function check_DKG() {
    # If the definition file URL is set and the lock file does not exist, start DKG ceremony
    if [ -n "${DEFINITION_FILE_URL}" ] && [ ! -f "${CHARON_LOCK_FILE}" ]; then
        echo "${INFO} Waiting for DKG ceremony..."
        charon dkg --definition-file="${DEFINITION_FILE_URL}" --data-dir="${CHARON_ROOT_DIR}" || {
            echo "${ERROR} DKG ceremony failed"
            exit 1
        }

    # If the definition file URL is not set and the lock file does not exist, wait for the definition file URL to be set
    elif [ -z "${DEFINITION_FILE_URL}" ] && [ ! -f "${CHARON_LOCK_FILE}" ]; then
        echo "${INFO} Set the definition file URL in the Charon config to start DKG ceremony..."
        sleep 1h # To let the user restore a backup
        exit 0

    else
        echo "${INFO} DKG ceremony already done. Process can continue..."
    fi
}

function run_charon() {
    exec charon run --private-key-file=$ENR_PRIVATE_KEY_FILE --lock-file=$CHARON_LOCK_FILE ${CHARON_EXTRA_OPTS}
}

########
# MAIN #
########

echo "${INFO} Getting the current beacon chain in use..."
get_beacon_node_endpoint

echo "${INFO} Getting the ENR..."
get_ENR

echo "${INFO} Checking for DKG ceremony..."
check_DKG

echo "${INFO} Starting charon..."
run_charon
