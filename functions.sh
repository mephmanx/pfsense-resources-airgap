#!/bin/bash

function baseDN() {
  ### BaseDN
  BASE_DN=""
  IFS='.' read -ra ADDR <<< "$INTERNAL_DOMAIN_NAME"
  LEN="${#ADDR[@]}"
  CT=1
  for i in "${ADDR[@]}"; do
    BASE_DN+="dc=$i"
    if [[ $CT -lt $LEN ]]; then
      BASE_DN+=","
      ((CT++))
    fi
  done
  echo $BASE_DN
  ####
}