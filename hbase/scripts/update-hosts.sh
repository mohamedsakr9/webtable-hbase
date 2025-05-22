#!/bin/bash
# Get container IPs from Docker network
for host in m1 m2 m3 hm1 hm2 rs1 rs2 rs3; do
  IP=$(getent hosts $host | awk "{ print \$1 }")
  if [ ! -z "$IP" ]; then
    # Check if entry already exists
    if ! grep -q "^$IP $host$" /etc/hosts; then
      echo "$IP $host" >> /etc/hosts
      echo "Added $IP $host to /etc/hosts"
    fi
  else
    echo "Warning: Could not resolve $host"
  fi
done