#!/bin/bash

# Docker entrypoint script for batch-heudiconv
# Note: This version runs as root initially to handle user mapping, then becomes non-root

# Simple user mapping if HOST_UID and HOST_GID are provided
if [ -n "$HOST_UID" ] && [ -n "$HOST_GID" ]; then
    current_uid=$(id -u)
    current_gid=$(id -g)
    
    if [ "$HOST_UID" != "$current_uid" ] || [ "$HOST_GID" != "$current_gid" ]; then
        echo "Adjusting permissions: UID=$HOST_UID, GID=$HOST_GID"
        chown -R "$HOST_UID:$HOST_GID" /data 2>/dev/null || true
    fi
fi

# Since we're already running as batchuser (via USER directive), just exec the command
cd /data

if [ "$#" -eq 0 ]; then
    exec /bin/bash
else
    exec "$@"
fi
