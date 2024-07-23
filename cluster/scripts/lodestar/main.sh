#!/bin/bash

# Wait for Charon to be ready
while true; do
    if curl -s http://localhost:3620/readyz | grep -q "ready"; then
        echo "Charon is ready."
        break
    else
        echo "Waiting for Charon to be ready..."
        sleep 60
    fi
done

./keystore-import.sh

./sign-exit

./run-validator.sh
