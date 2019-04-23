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

  log "Discovered checksum url $pubsub_checksum_url"
  PRODUCT_RESPONSE=$(curl -w '%{http_code}' -H "Accept: application/json" -H "Content-Type: application/json" -H "Authorization: Bearer $PIVNET_ACCESS_TOKEN" -sL $pubsub_checksum_url -o $CHECKSUM_FILE)

  if [ "$PRODUCT_RESPONSE" -eq "200" ]; then
    # Nothing to do, all is well.
    true
  elif [ "$PRODUCT_RESPONSE" -eq "401" ]; then
    log "The user could not be authenticated."
    exit 1
  elif [ "$PRODUCT_RESPONSE" -eq "403" ]; then
    log "The user does not have access to download files from this release."
    exit 1
  elif [ "$PRODUCT_RESPONSE" -eq "404" ]; then
    log "The product or release cannot be found."
    exit 1
  elif [ "$PRODUCT_RESPONSE" -eq "451" ]; then
    log "The user has not accepted the current EULA for this release. Please log in to PivNet and accept the license agreement."
    exit 1
  else
    log "Unexpected response from the checksum url: $PRODUCT_RESPONSE"
    exit 1
  fi

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


