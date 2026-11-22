#!/bin/bash
# Quick health check for the SabziCart server
echo "=== SabziCart health check ==="
echo "Host:       $(hostname)"
echo "Uptime:     $(uptime -p)"
echo "Users:      $(wc -l < /etc/passwd) accounts in /etc/passwd"
echo "Processes:  $(ps aux | wc -l) running"
echo "Failed services:"
systemctl --failed --no-legend | sed 's/^/   /'
echo "=== done ==="
