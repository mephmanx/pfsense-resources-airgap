#!/bin/bash

args=()
for entry in "$@"; do
  if ! grep -q ":" <<< "$entry"; then
    echo "Arguments must be of the form <param name>:<param value>"
    exit 1
  fi
  IFS=':' read -ra line_entry <<<"$entry"
  args+=("${line_entry[0]}:${line_entry[1]}")
done

touch /tmp/env.sh
for arg in "${args[@]}"; do
  IFS=':' read -ra line_entry <<<"$arg"
  echo "Setting env variable ${line_entry[0]} to value ${line_entry[1]}"
  echo "export ${line_entry[0]}=${line_entry[1]}" > /tmp/env.sh
done
chmod +x /tmp/env.sh
source /tmp/env.sh
rm -rf /tmp/env.sh