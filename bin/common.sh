#!/bin/bash

# This file is included by the in/check scripts in assets. It contains a variety of general
# use functions between the two files.

function log() {
  echo $1 >&2
  echo $1 >> "/var/log/solace-product-download.log"
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

function pivnetAuthentication() {
  export PIVNET_REFRESH_TOKEN=$(getPayloadProperty ".source.pivnet_token")
  if [ -z $PIVNET_REFRESH_TOKEN ]; then
    log "No Pivnet Refresh Token provided! Cannot fetch refresh token from pivnet as a result"
    exit 1
  fi

  pivnet login --api-token "$PIVNET_REFRESH_TOKEN" >&2
}

function getPubsubReleaseVersion() {
  export PUBSUB_PIVNET_VERSION="$(getPayloadProperty ".source.version")"
  if [ -z "$PUBSUB_PIVNET_VERSION" ]; then 
    export PUBSUB_PIVNET_VERSION="$(pivnet releases -p solace-pubsub --format json | jq -r '.[0].version')"
    log "No Pubsub version specified, will use latest ($PUBSUB_PIVNET_VERSION)"
  fi
}

function downloadChecksumFromPivnet() {
  export CHECKSUM_DIR=$(mktemp -d)

  getPubsubReleaseVersion

  export PUBSUB_VERSION_LIST="$(pivnet product-files -p solace-pubsub -r $PUBSUB_PIVNET_VERSION --format json)"
  export PUBSUB_CHECKSUM_ID="$(echo $PUBSUB_VERSION_LIST | jq -r '.[] | select(.name | contains("Checksum")) | .id')"
  pivnet download-product-files -p solace-pubsub -r "$PUBSUB_PIVNET_VERSION" -i "$PUBSUB_CHECKSUM_ID" --accept-eula -d "$CHECKSUM_DIR" >&2
  export CHECKSUM_FILE="$CHECKSUM_DIR/$(ls $CHECKSUM_DIR | head -1)"

  log "Saved checksum for version $PUBSUB_PIVNET_VERSION to $CHECKSUM_FILE"
}

function getReleaseFolder() {
  if [ ! -z "$(getPayloadProperty ".source.pivnet_token")" ]; then
    version="$1"
    majorMinor="$(echo $version | cut -d \. -f 1-2)."
    patch="$(echo $version | sed "s/$majorMinor//g")"
    patches=($(pivnet releases -p solace-pubsub --format json | jq -r ".[].version" | grep "$majorMinor" | grep -v "$version" | sed "s/$majorMinor//g"))
    export PUBSUB_FOLDER="Current"
    for (( i = 0; i < ${#patches[@]}; i++ )); do
      if [ "${patches[$i]}" -gt "$patch" ]; then
        log "Found newer patch on Pivnet than specified version, product file will be in Archive directory"
        export PUBSUB_FOLDER="Archive"
        break
      fi
    done
  else
    export PUBSUB_FOLDER="Current"
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
  
  getReleaseFolder "$PUBSUB_VERSION"
}


