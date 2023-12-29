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
  VALIDATOR_EXTRA_OPTS="--validators-proposer-blinded-blocks-enabled=true --validators-builder-registration-default-enabled=true $VALIDATOR_EXTRA_OPTS"
fi

export CHARON_P2P_EXTERNAL_HOSTNAME=${_DAPPNODE_GLOBAL_DOMAIN}

CHARON_PID=0
VALIDATOR_CLIENT_PID=0

#############
# FUNCTIONS #
#############

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
    -X POST "http://my.dappnode/data-send?key=ENR-Cluster-${CLUSTER_ID}&data=${ENR}" ||
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
    sleep 180 # To let the user restore a backup
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

function run_validator_client() {
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
      ${VALIDATOR_EXTRA_OPTS}
  ) &
  VALIDATOR_CLIENT_PID=$!
}

########
# MAIN #
########

echo "${INFO} get the current beacon chain in use"
get_beacon_node_endpoint

echo "${INFO} getting the ENR..."
get_ENR

echo "${INFO} checking for DKG ceremony..."
check_DKG

echo "${INFO} starting charon..."
run_charon

echo "${INFO} starting validator client..."
run_validator_client

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
