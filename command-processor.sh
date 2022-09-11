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

for arg in "${args[@]}"; do
  IFS=':' read -ra line_entry <<<"$arg"
  printf "export %s=%s\n" "${line_entry[0]}" "${line_entry[1]}"
done