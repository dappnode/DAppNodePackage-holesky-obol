#!/bin/bash

VALIDATOR_KEYS_DIR=${CHARON_ROOT_DIR}/validator_keys

function import_keystores_to_lodestar() {

    VALIDATOR_CLIENT_KEYS_DIR=${VALIDATOR_DATA_DIR}/keystores

    for f in "${VALIDATOR_KEYS_DIR}"/keystore-*.json; do

        # Read the JSON and get the pubkey field
        pubkey=$(jq -r '.pubkey' "${f}")

        # Check if the keystore is already imported
        if [[ -d "${VALIDATOR_CLIENT_KEYS_DIR}/0x${pubkey}" ]]; then
            echo "Keystore for pubkey ${pubkey} already imported"

        else
            echo "Importing key ${f}"

            # Import keystore with password.
            ${VALIDATOR_SERVICE_BIN} \
                --dataDir="${VALIDATOR_DATA_DIR}" \
                validator import \
                --network="${NETWORK}" \
                --importKeystores="${f}" \
                --importKeystoresPassword="${f//json/txt}"
        fi
    done
}

function sign_exit() {

    if [ "$SIGN_EXIT" != true ]; then
        echo "${INFO} Signing exit is disabled. Skipping..."
        return
    fi

    # Validate exit epoch
    if [ -n "$EXIT_EPOCH" ]; then

        if [[ "$EXIT_EPOCH" =~ ^[0-9]+$ ]] && [ "$EXIT_EPOCH" -ge 1 ]; then
            echo "${INFO} Signing exit with EXIT_EPOCH=${EXIT_EPOCH}"
        else
            echo "${ERROR} EXIT_EPOCH is not valid. It must be a positive integer."
            return
        fi

    else
        echo "${INFO} Signing exit without EXIT_EPOCH"
    fi

    sign_exit_lodestar
}

function sign_exit_lodestar() {

    local flags="validator \
        voluntary-exit \
        --beaconNodes=http://localhost:3600 \
        --dataDir=${VALIDATOR_DATA_DIR} \
        --network=${NETWORK} \
        --yes"

    if [ -n "$EXIT_EPOCH" ]; then
        flags="${flags} --exitEpoch=${EXIT_EPOCH}"
    fi

    # shellcheck disable=SC2086
    ${VALIDATOR_SERVICE_BIN} ${flags}
}

function run_lodestar() {

    local flags="validator \
        --network=${NETWORK} \
        --dataDir=${VALIDATOR_DATA_DIR} \
        --beaconNodes=http://localhost:3600 \
        --metrics=true \
        --metrics.address=0.0.0.0 \
        --metrics.port=${VALIDATOR_METRICS_PORT} \
        --graffiti=${GRAFFITI} \
        --suggestedFeeRecipient=${DEFAULT_FEE_RECIPIENT} \
        --distributed"

    if [ -n "$VALIDATOR_EXTRA_OPTS" ]; then
        flags="${flags} ${VALIDATOR_EXTRA_OPTS}"
    fi

    # shellcheck disable=SC2086
    exec ${VALIDATOR_SERVICE_BIN} ${flags}
}

# While VALIDATOR_KEYS_DIR=${CHARON_ROOT_DIR}/validator_keys does not have any keys, wait for the keys to be imported using inotifywait
while [ ! "$(ls -A ${VALIDATOR_KEYS_DIR})" ]; do
    echo "${INFO} No keys found in ${VALIDATOR_KEYS_DIR}. Waiting for keys to be imported..."
    inotifywait -e create -e moved_to -e modify -e close_write -r "${VALIDATOR_KEYS_DIR}"
done
