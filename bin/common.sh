#!/bin/bash

# This file is included by the in/check scripts in assets. It contains a variety of general
# use functions between the two files.

export PUBSUB_PIVNET_URL="https://network.pivotal.io/api/v2/products/solace-pubsub/releases"
export PUBSUB_PIVNET_LATEST="$PUBSUB_PIVNET_URL/latest"

function log() {
  echo $1 >&2
}

function readPayload() {
  if [ -z "$PAYLOAD" ]; then
    export PAYLOAD=$(mktemp)
    cat > "$PAYLOAD" <&0
  fi
}

function getPayloadProperty() {
  readPayload
  echo $(jq -r "$1 // \"\"" < $PAYLOAD)
}

function getPubsubReleaseVersion() {
  export PUBSUB_PIVNET_VERSION_ID=$(curl -s $PUBSUB_PIVNET_LATEST | jq -r '.id // ""')
}

function getPivnetRefreshToken() {
  if [ -z "$PIVNET_ACCESS_TOKEN" ]; then
    log "Generating pivnet access token from refresh token"
    export PIVNET_REFRESH_TOKEN=$(getPayloadProperty ".source.pivnet_token")
    if [ -z $PIVNET_REFRESH_TOKEN ]; then
      log "No Pivnet Refresh Token provided! Cannot fetch refresh token from pivnet as a result"
      exit 1
    fi
    export PIVNET_ACCESS_TOKEN="$(curl -s -X POST https://network.pivotal.io/api/v2/authentication/access_tokens -d "{\"refresh_token\":\"$PIVNET_REFRESH_TOKEN\"}" | jq -r .access_token)"  
    if [ -z "$PIVNET_ACCESS_TOKEN" ]; then
      log "Invalid UAA API token (refresh token) was provided in source.pivnet_token, no access token could be retrieved from it"
      exit 1
    fi
    export PIVNET_HEADERS="-H \"Accept: application/json\" -H \"Content-Type: application/json\" -H \"Authorization: Bearer $PIVNET_ACCESS_TOKEN\""
  fi
}

function acceptPivnetEula() {
  if [ -z "$PIVNET_HEADERS" ]; then
    getPivnetRefreshToken
  fi
  eula_url="$1/eula_acceptance"
  eula="$(eval curl $PIVNET_HEADERS -s -w '%{http_code}' -o /dev/null -X POST $eula_url)"
  if [ "$eula" != "200" ]; then
    log "Failed to accept EULA for $eula_url. Got $eula, expected 200"
    exit 1
  fi
}

function downloadChecksumFromPivnet() {
  export CHECKSUM_FILE=$(mktemp)

  if [ -z "$PIVNET_HEADERS" ]; then
    getPivnetRefreshToken
  fi

  if [ -z "$PUBSUB_PIVNET_VERSION_ID" ]; then 
    getPubsubReleaseVersion
  fi

  pubsub_pivnet_version_url="$PUBSUB_PIVNET_URL/$PUBSUB_PIVNET_VERSION_ID"
  pubsub_pivnet_product_url="$pubsub_pivnet_version_url/product_files"
  pubsub_checksum_id="$(curl -s $pubsub_pivnet_product_url | jq -r '.product_files[] | select(.name | contains("Checksum")) | .id')"
  pubsub_checksum_url="$pubsub_pivnet_product_url/$pubsub_checksum_id/download"

  acceptPivnetEula $pubsub_pivnet_version_url

  log "Discovered checksum url $pubsub_checksum_url"
  curl -H "Accept: application/json" -H "Content-Type: application/json" -H "Authorization: Bearer $PIVNET_ACCESS_TOKEN" -sL $pubsub_checksum_url -o $CHECKSUM_FILE
}

function parseChecksum() {
  log "Parsing checksum file"
  checksum=$(cat $1)
  log "$checksum"
  log
  checksum_array=($checksum)
  export PUBSUB_FILENAME="$(basename ${checksum_array[1]})"
  export PUBSUB_VERSION="$(echo $PUBSUB_FILENAME | cut -d- -f3)"
  export PUBSUB_GA="$(echo $PUBSUB_VERSION | cut -d \. -f 1-2)GA"
}


