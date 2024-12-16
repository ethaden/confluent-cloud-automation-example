#!/bin/bash
# This file reads data from "api-key.txt" in this folder if that file exists. If not, it looks for environment variables.
# It can be customized to get the credentials from different sources as well.

if [ -z "${CONFLUENT_CLOUD_API_KEY}" -o -z "${CONFLUENT_CLOUD_API_SECRET}" ]; then
  CONFLUENT_API_KEY_FILE="api-key.txt"
  if [ -e ${CONFLUENT_API_KEY_FILE} ]; then
    export CONFLUENT_CLOUD_API_KEY=$(grep "API key:$" -A 1 ${CONFLUENT_API_KEY_FILE} | sed -n "2p")
    export CONFLUENT_CLOUD_API_SECRET=$(grep "API secret:$" -A 1 ${CONFLUENT_API_KEY_FILE} | sed -n "2p")
  # Comment the next three lines if this project does not use Confluent Cloud
  else
    printf "Please set environment variables CONFLUENT_CLOUD_API_KEY and CONFLUENT_CLOUD_API_SECRET or provide an API file ${CONFLUENT_API_KEY_FILE} as exported during creation by the confluent website\n" >&2
    exit 1
  fi
fi

# Change the contents of this output to get the environment variables
# of interest. The output must be valid JSON, with strings for both
# keys and values.
cat <<EOF
{
"api_key": "${CONFLUENT_CLOUD_API_KEY}",
"api_secret": "${CONFLUENT_CLOUD_API_SECRET}"
}
EOF
