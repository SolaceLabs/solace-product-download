#!/bin/bash

export SCRIPT="$( basename "${BASH_SOURCE[0]}" )"
export SCRIPTPATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

export SOLACE_PRODUCT_DOWNLOAD_NAME=${SOLACE_PRODUCT_DOWNLOAD_NAME:-solace-product-download}
export SOLACE_PRODUCT_DOWNLOAD_ORG=${SOLACE_PRODUCT_DOWNLOAD_ORG:-solace}
export SOLACE_PRODUCT_DOWNLOAD_DOCKER_NAME="$SOLACE_PRODUCT_DOWNLOAD_ORG/$SOLACE_PRODUCT_DOWNLOAD_NAME"
export SOLACE_PRODUCT_DOWNLOAD_DOCKER_TARGET="$SOLACE_PRODUCT_DOWNLOAD_NAME"

export DOCKER_USERNAME=${DOCKER_USERNAME:-}
export DOCKER_PASSWORD=${DOCKER_PASSWORD:-}
export DOCKER_REGISTRY=${DOCKER_REGISTRY:-}

function showUsage() {
  echo "Usage: $SCRIPT [OPTIONS]"
  echo "OPTIONS:"
  echo "  -h              Show help"
  echo "  -u <username>   Username for docker registry, alternatively provide DOCKER_USERNAME"
  echo "  -p <password>   Password for docker registry, alternatively provide DOCKER_PASSWORD"
  echo "  -r <registry>   Specify a docker registry, defaults to docker hub, alternatively provide DOCKER_REGISTRY"
  echo "  -l              Local build only, does not push to docker hub, alternatively provide DOCKER_LOCAL_ONLY"
}

while getopts "u:p:r:lh" arg; do
  case "${arg}" in
    u)
      export DOCKER_USERNAME=$OPTARG
      ;;
    p)
      export DOCKER_PASSWORD=$OPTARG
      ;;
    r)
      export DOCKER_REGISTRY=$OPTARG
      ;;
    l)
      export DOCKER_LOCAL_ONLY=1
      ;;
    h)
      showUsage
      exit 0
      ;;
    \?)
    >&2 echo
    >&2 echo "Invalid option: -$OPTARG" >&2
    >&2 echo
    showUsage
    exit 1
    ;;
  esac
done

echo "Building $SOLACE_PRODUCT_DOWNLOAD_DOCKER_NAME"

sudo docker build . -t "$SOLACE_PRODUCT_DOWNLOAD_DOCKER_NAME"

if [ -z $DOCKER_LOCAL_ONLY ]; then
  if [ ! -z $DOCKER_REGISTRY ]; then
    echo "Using docker registry $DOCKER_REGISTRY"
    export SOLACE_PRODUCT_DOWNLOAD_DOCKER_TARGET="$DOCKER_REGISTRY/$SOLACE_PRODUCT_DOWNLOAD_NAME"
    echo "Tagging $SOLACE_PRODUCT_DOWNLOAD_DOCKER_NAME with $SOLACE_PRODUCT_DOWNLOAD_DOCKER_TARGET"
    sudo docker tag $SOLACE_PRODUCT_DOWNLOAD_DOCKER_NAME $SOLACE_PRODUCT_DOWNLOAD_DOCKER_TARGET
  else
    echo "Using docker hub"
  fi

  if [ ! -z $DOCKER_USERNAME ] && [ ! -z $DOCKER_PASSWORD ]; then
    echo "Logging into docker as $DOCKER_USERNAME"
    sudo docker login -u "$DOCKER_USERNAME" -p "$DOCKER_PASSWORD"
  else
    echo "No docker credentials provided, not attempting login"
  fi

  echo "Pushing $SOLACE_PRODUCT_DOWNLOAD_DOCKER_TARGET to $DOCKER_REGISTRY"
  sudo docker push "$SOLACE_PRODUCT_DOWNLOAD_DOCKER_TARGET"
else
  echo "Local build only, will not push to docker registry"
fi

