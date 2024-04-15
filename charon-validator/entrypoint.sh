#!/bin/bash
# Exit on error
set -eo pipefail

#############
# VARIABLES #
#############
ERROR="[ ERROR-charon-manager ]"
WARN="[ WARN-charon-manager ]"
INFO="[ INFO-charon-manager ]"

CHARON_ROOT_DIR=/opt/charon/.charon
CREATE_ENR_FILE=${CHARON_ROOT_DIR}/create_enr.txt
ENR_PRIVATE_KEY_FILE=${CHARON_ROOT_DIR}/charon-enr-private-key
ENR_FILE=${CHARON_ROOT_DIR}/enr
DEFINITION_FILE_URL_FILE=${CHARON_ROOT_DIR}/definition_file_url.txt

CHARON_LOCK_FILE=${CHARON_ROOT_DIR}/cluster-lock.json
REQUEST_BODY_FILE=${CHARON_ROOT_DIR}/request-body.json
VALIDATOR_KEYS_DIR=${CHARON_ROOT_DIR}/validator_keys

if [ -n "$DEFINITION_FILE_URL" ]; then
    echo $DEFINITION_FILE_URL >$DEFINITION_FILE_URL_FILE
fi

if [ "$ENABLE_MEV_BOOST" = true ]; then
    CHARON_EXTRA_OPTS="--builder-api $CHARON_EXTRA_OPTS"

    # Teku
    if [ "$VALIDATOR_CLIENT" = "teku" ]; then
        VALIDATOR_EXTRA_OPTS="--validators-proposer-blinded-blocks-enabled=true --validators-builder-registration-default-enabled=true $VALIDATOR_EXTRA_OPTS"
    # Lodestar (by default)
    else
        VALIDATOR_EXTRA_OPTS="--builder=true --builder.selection=builderonly $VALIDATOR_EXTRA_OPTS"
    fi
fi

export CHARON_P2P_EXTERNAL_HOSTNAME=${_DAPPNODE_GLOBAL_DOMAIN}

CHARON_PID=0
VALIDATOR_CLIENT_PID=0

#############
# FUNCTIONS #
#############

# Finds the first .tar.gz or .zip file in the IMPORT_DIR
function find_import_file() {
    find "${IMPORT_DIR}" -type f \( -name "*.tar.gz" -o -name "*.zip" -o -name "*.tar.xz" \) | head -1
}

# Moves existing files in the .charon directory to a timestamped old-charon directory
function move_old_charon() {
    if [ -d "${CHARON_ROOT_DIR}" ] && [ "$(ls -A ${CHARON_ROOT_DIR})" ]; then
        TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
        OLD_CHARON_DIR="/opt/charon/old-charons/${TIMESTAMP}"
        echo "${INFO} Moving existing files in ${CHARON_ROOT_DIR} to ${OLD_CHARON_DIR}..."
        mkdir -p "${OLD_CHARON_DIR}"
        mv ${CHARON_ROOT_DIR}/* "${OLD_CHARON_DIR}"
    else
        echo "${INFO} No existing files found in ${CHARON_ROOT_DIR} to move."
    fi
}

# Extracts the import file into the .charon directory
function extract_file_into_charon_dir() {
    echo "${INFO} Starting extraction of ${1} into ${CHARON_ROOT_DIR}"
    if [[ "${1}" == *.tar.gz ]]; then
        tar -xzf "${1}" -C ${CHARON_ROOT_DIR} && echo "${INFO} Extraction complete."
    elif [[ "${1}" == *.tar.xz ]]; then
        tar -xJf "${1}" -C ${CHARON_ROOT_DIR} && echo "${INFO} Extraction complete."
    elif [[ "${1}" == *.zip ]]; then
        unzip -o "${1}" -d ${CHARON_ROOT_DIR} && echo "${INFO} Extraction complete."
    fi
}

# Remove all keys from the validator service
function empty_lodestar_keys() {
    echo "${INFO} Emptying validator service keys..."
    rm -rf ${VALIDATOR_KEYS_DIR}/cache/*
    rm -rf ${VALIDATOR_KEYS_DIR}/keystores/*
    rm -rf ${VALIDATOR_KEYS_DIR}/secrets/*
}

# Main function to handle Charon file import
function handle_charon_file_import() {
    echo "${INFO} Starting Charon file import process in ${IMPORT_DIR}"
    if [ -n "${IMPORT_DIR}" ] && [ -d "${IMPORT_DIR}" ]; then

        echo "${INFO} Searching for .tar.gz, .tar.xz or .zip files in ${IMPORT_DIR}"
        IMPORT_FILE=$(find_import_file)

        if [ -n "${IMPORT_FILE}" ]; then
            echo "${INFO} Found file to import: ${IMPORT_FILE}"
            move_old_charon
            extract_file_into_charon_dir "${IMPORT_FILE}"
            rm -f "${IMPORT_FILE}"
            empty_lodestar_keys
            echo "${INFO} Import file processing complete."
        else
            echo "${INFO} No files to import."
        fi
    else
        echo "${INFO} IMPORT_DIR is not set or does not exist. No import process to be performed."
    fi
}

function get_beacon_node_endpoint() {
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

        export CHARON_BEACON_NODE_ENDPOINTS=$EXTERNAL_BEACON_NODE_ENDPOINT
        echo "Using external beacon node endpoint: $CHARON_BEACON_NODE_ENDPOINTS"
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

    # If CREATE_ENR_FILE exists but ENR_FILE does not, create ENR_FILE
    if [[ -f "$CREATE_ENR_FILE" ]] && [[ ! -f "$ENR_FILE" ]]; then
        echo "${INFO} ENR file does not exist, creating it..."
        grep "enr:" ${CREATE_ENR_FILE} | cut -d " " -f 2 >$ENR_FILE
    fi

    # If ENR_FILE exists, get ENR from it and publish it to dappmanager
    if [[ -f "$ENR_FILE" ]]; then
        ENR=$(cat $ENR_FILE)
        echo "${INFO} ENR: ${ENR}"
        echo "${INFO} Publishing ENR to dappmanager..."
        post_ENR_to_dappmanager
    fi
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
            exit 1
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
        sleep 300 # To let the user restore a backup
        exit 0

    else
        echo "${INFO} DKG ceremony already done. Process can continue..."
    fi
}

function run_charon() {
    # Start charon in a subshell in the background
    (
        exec charon run --private-key-file=$ENR_PRIVATE_KEY_FILE --lock-file=$CHARON_LOCK_FILE ${CHARON_EXTRA_OPTS}
    ) &
    CHARON_PID=$!
}

function import_keystores_to_lodestar() {

    VALIDATOR_CLIENT_KEYS_DIR=${VALIDATOR_DATA_DIR}/keystores

    for f in ${VALIDATOR_KEYS_DIR}/keystore-*.json; do

        # Read the JSON and get the pubkey field
        pubkey=$(jq -r '.pubkey' ${f})

        # Check if the keystore is already imported
        if [[ -d "${VALIDATOR_CLIENT_KEYS_DIR}/0x${pubkey}" ]]; then
            echo "Keystore for pubkey ${pubkey} already imported"

        else
            echo "Importing key ${f}"

            # Import keystore with password.
            node ${VALIDATOR_SERVICE_BIN} \
                --dataDir="${VALIDATOR_DATA_DIR}" \
                validator import \
                --network="${NETWORK}" \
                --importKeystores="${f}" \
                --importKeystoresPassword="${f//json/txt}"
        fi
    done
}

function run_lodestar() {
    (
        exec node ${VALIDATOR_SERVICE_BIN} validator \
            --network="${NETWORK}" \
            --dataDir="${VALIDATOR_DATA_DIR}" \
            --beaconNodes="http://localhost:3600" \
            --metrics="true" \
            --metrics.address="0.0.0.0" \
            --metrics.port="${VALIDATOR_METRICS_PORT}" \
            --graffiti="${GRAFFITI}" \
            --suggestedFeeRecipient="${DEFAULT_FEE_RECIPIENT}" \
            --distributed \
            --useProduceBlockV3=false \
            ${VALIDATOR_EXTRA_OPTS}
    ) &
    VALIDATOR_CLIENT_PID=$!
}

function run_teku() {
    (
        exec ${VALIDATOR_SERVICE_BIN} --log-destination=CONSOLE \
            validator-client \
            --beacon-node-api-endpoint=http://localhost:3600 \
            --data-base-path=${VALIDATOR_DATA_DIR} \
            --metrics-enabled=true \
            --metrics-interface 0.0.0.0 \
            --metrics-port 8008 \
            --metrics-host-allowlist=* \
            --validator-api-enabled=false \
            --validators-keystore-locking-enabled=false \
            --validator-keys=${VALIDATOR_KEYS_DIR}:${VALIDATOR_KEYS_DIR} \
            --network=${NETWORK} \
            --validators-proposer-default-fee-recipient=${DEFAULT_FEE_RECIPIENT} \
            --validators-graffiti=${GRAFFITI} \
            --Xblock-v3-enabled=false \
            ${VALIDATOR_EXTRA_OPTS}
    ) &
    VALIDATOR_CLIENT_PID=$!
}

########
# MAIN #
########

echo "${INFO} Checking if there are charon settings to import..."
handle_charon_file_import

echo "${INFO} Getting the current beacon chain in use..."
get_beacon_node_endpoint

echo "${INFO} Getting the ENR..."
get_ENR

echo "${INFO} Checking for DKG ceremony..."
check_DKG

echo "${INFO} Starting charon..."
run_charon

if [ "$VALIDATOR_CLIENT" = "teku" ]; then
    echo "${INFO} Starting teku validator service..."
    run_teku
else
    echo "${INFO} Importing keystores to lodestar validator service..."
    import_keystores_to_lodestar
    echo "${INFO} Starting lodestar validator service..."
    run_lodestar
fi

# This wait will exit as soon as any of the background processes exits
wait -n

# Check which process has exited and exit the other one
if ! kill -0 $CHARON_PID 2>/dev/null; then
    echo "${INFO} Charon process has exited. Exiting validator client..."
    kill -SIGTERM $VALIDATOR_CLIENT_PID 2>/dev/null
elif ! kill -0 $VALIDATOR_CLIENT_PID 2>/dev/null; then
    echo "${INFO} Validator client process has exited. Exiting charon..."
    kill -SIGTERM $CHARON_PID 2>/dev/null
fi

echo "${INFO} All processes stopped. Exiting..."
