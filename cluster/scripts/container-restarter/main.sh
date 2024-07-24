#!/bin/bash

INFO="[ INFO | container-restarter ]"

echo "${INFO} Enabling restart on artifact upload in ${IMPORT_DIR}"

# Monitor the IMPORT_DIR for new files and restart the charon process if a new file is detected
inotifywait -m -q -e close_write --format '%f' "${IMPORT_DIR}" | while read -r filename; do
    echo "${INFO} Detected new file: ${filename}"

    # Check if the new file matches the expected patterns
    if [[ "${filename}" =~ \.zip$|\.tar\.gz$|\.tar\.xz$ ]]; then

        supervisor_pid=$(cat /opt/supervisor/supervisord.pid)

        echo "${INFO} Artifact ${filename} uploaded, triggering container restart..."

        # Forcefully terminate the charon process to trigger a container restart
        echo "${INFO} Sending supervisord signal SIGKILL..."
        kill -s SIGKILL "${supervisor_pid}"
    fi
done
