#!/bin/bash

INFO="[ INFO | lodestar-keystore-import ]"

function import_keystores_to_lodestar() {

    local charon_keys_dir=${CHARON_ROOT_DIR}/validator_keys
    local lodestar_keys_dir=${VALIDATOR_DATA_DIR}/keystores

    for f in "${charon_keys_dir}"/keystore-*.json; do

        # Read the JSON and get the pubkey field
        pubkey=$(jq -r '.pubkey' "${f}")

        # Check if the keystore is already imported
        if [[ -d "${lodestar_keys_dir}/0x${pubkey}" ]]; then
            echo "$INFO Keystore for pubkey ${pubkey} already imported"

        else
            echo "$INFO Importing key ${f}"

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

import_keystores_to_lodestar
