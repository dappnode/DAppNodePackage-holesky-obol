#!/bin/sh

# These envs are defined in the compose file: MONITORING_URL, MONITORING_CREDENTIALS, ACTIVE_CHARONS_NUMBER

if [ -z "$MONITORING_URL" ] || [ -z "$MONITORING_CREDENTIALS" ]; then
    echo "MONITORING_URL and MONITORING_CREDENTIALS must be set in the config to enable monitoring"
    exit 0 # To avoid restart
fi

# If active charons is not a number or is <=0, then exits
if ! [ "$ACTIVE_CHARONS_NUMBER" -eq "$ACTIVE_CHARONS_NUMBER" ] 2>/dev/null || [ "$ACTIVE_CHARONS_NUMBER" -le 0 ]; then
    echo "ACTIVE_CHARONS_NUMBER must be a number greater than 0"
    exit 0 # To avoid restart
fi

# Generate charon and validator targets based on the number of active charons
# Example: If ACTIVE_CHARONS_NUMBER=3, then <CHARON_TARGETS> will be replaced by ["charon-validator-1:3620", "charon-validator-2:3620", "charon-validator-3:3620"]
charon_targets=""
validator_targets=""
for i in $(seq 1 $ACTIVE_CHARONS_NUMBER); do
    if [ "$charon_targets" != "" ]; then
        charon_targets="$charon_targets, "
        validator_targets="$validator_targets, "
    fi
    charon_targets="${charon_targets}\"charon-validator-$i:3620\""
    validator_targets="${validator_targets}\"charon-validator-$i:8008\""
done

# Wrap the generated strings in brackets (arrays)
charon_targets="[$charon_targets]"
validator_targets="[$validator_targets]"

# Replace placeholders in the configuration template
sed -e "s|<MONITORING_URL>|$MONITORING_URL|g" \
    -e "s|<MONITORING_CREDENTIALS>|$MONITORING_CREDENTIALS|g" \
    -e "s|<CHARON_TARGETS>|$charon_targets|g" \
    -e "s|<VALIDATOR_TARGETS>|$validator_targets|g" \
    $TEMPLATE_CONFIG_FILE >$CONFIG_FILE

exec /bin/prometheus --config.file $CONFIG_FILE_PATH
