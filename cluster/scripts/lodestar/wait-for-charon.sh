#!/bin/bash

INFO="[ INFO | lodestar-wait ]"

# Wait for Charon to be ready
while true; do
    if curl -s http://localhost:3620/readyz | grep -q "ready"; then
        echo "$INFO Charon is ready. Lodestar can start."
        break
    else
        echo "$INFO Waiting for Charon to be ready before launching lodestar..."
        sleep 60
    fi
done
