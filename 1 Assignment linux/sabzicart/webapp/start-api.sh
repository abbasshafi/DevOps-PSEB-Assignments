#!/bin/bash
# Starts the SabziCart practice web server.
# It reads the port from the app config file.
CONF="$HOME/sabzicart/webapp/config/app.conf"
PORT=$(grep -E '^[[:space:]]*port[[:space:]]*=' "$CONF" | head -n 1 | cut -d= -f2 | tr -d ' ')
echo "SabziCart API starting on port $PORT"
echo "Serving files from $HOME/sabzicart/webapp/public"
exec python3 -m http.server "$PORT" --bind 127.0.0.1 --directory "$HOME/sabzicart/webapp/public"
