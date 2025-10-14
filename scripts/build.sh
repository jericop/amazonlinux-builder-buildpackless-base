#!/usr/bin/env bash

set -euo pipefail

readonly ROOT_DIR="$(cd "$(dirname "${0}")/.." && pwd)"
readonly BIN_DIR="${ROOT_DIR}/.bin"
readonly BUILD_DIR="${ROOT_DIR}/build"

# shellcheck source=SCRIPTDIR/.util/tools.sh
source "${ROOT_DIR}/scripts/.util/tools.sh"

# shellcheck source=SCRIPTDIR/.util/print.sh
source "${ROOT_DIR}/scripts/.util/print.sh"

########################################
# Functions
########################################
function repo::prepare() {
  util::print::title "Preparing repo..."

  rm -rf "${BUILD_DIR}"

  mkdir -p "${BIN_DIR}"
  mkdir -p "${BUILD_DIR}"

  export PATH="${BIN_DIR}:${PATH}"
}

function tools::install() {
  local token
  token="${1}"

  util::tools::pack::install \
    --directory "${BIN_DIR}" \
    --token "${token}"
}

cleanup() {
    log_message "STATE: Stopping local registry"
    docker stop "${registry_name}" > /dev/null 2>&1
}

log_message() {
    local message="$1"
    echo "$(date +'%Y-%m-%d %H:%M:%S') - ${message}"
}

usage() {
printf "Usage: $0 [-c -i <image_ref>] [-i <image_ref2>] ...

Options:
    -c                The script will cleanup after itself
    -h                Prints this help message
    -i image_ref      The complete image reference to push to (can be specified multiple times)
                      (example: 'localhost:5001/amazonlinux-builder:v1.0.0')

"
exit 1
}

########################################
# Default values
########################################
builder_name=host-network-builder
cleanup_flag=0
repo_name="amazonlinux-builder"
registry_name="cnb"
registry_port=5041
image_push=0
image_refs=()  # array of image references to push to
token="" # can be empty or set to a valid token and is used for downloading pack and jam binaries

########################################
# Options
########################################
# parse command-line options
while getopts ":chi:" opt; do
    case "$opt" in
        c )
            cleanup_flag=1
            ;;
        h )
            usage
            ;;
        i )
            image_ref=${OPTARG}
            if [ -n "$image_ref" ]; then
                log_message "STATE: Image reference provided as $image_ref"
                image_refs+=("$image_ref")
                image_push=1
            else
                echo "ERROR: Empty image reference string"
                exit 1
            fi
            ;;
        : )
            echo "ERROR: -$OPTARG requires an argument"
            exit 1
            ;;
        ? )
            echo "ERROR: Invalid option: -$OPTARG"
            exit 1
            ;;
    esac
done

########################################
# Script starts here
########################################

# https://github.com/docker/buildx/issues/166#issuecomment-1804970076
# First, we need to create our own buildx builder that uses the host nework and docker-container driver so that we can get multiarch support
log_message "Setting up docker buildx builder"
docker buildx use "${builder_name}" > /dev/null 2>&1 || docker buildx create --name "${builder_name}" --driver docker-container --driver-opt network=host --bootstrap --use > /dev/null 2>&1

# start a registry
log_message "STATE: Setting up a local registry on port ${registry_port}"
docker container inspect "${registry_name}" > /dev/null 2>&1 || docker run -d -e REGISTRY_STORAGE_DELETE_ENABLED=true -p "${registry_port}":5000 --rm --name "${registry_name}" registry:2 > /dev/null 2>&1

repo::prepare

tools::install "${token}"

local_image="localhost:${registry_port}/${repo_name}:latest"

log_message "STATE: Creating images (this will take a while)..."
pack config experimental true
pack builder create ${local_image} --config builder.toml --publish --verbose

if [[ "${image_push}" -eq 1 ]]; then
    log_message "STATE: Copying images to ${#image_refs[@]} destination(s)"
    for image_ref in "${image_refs[@]}"; do
        log_message "STATE: Copying image to ${image_ref}..."
        crane copy ${local_image} ${image_ref}
        log_message "STATE: Image copied to ${image_ref}"
    done
    log_message "STATE: All images copied successfully"
fi

if [[ "${cleanup_flag}" -eq 1 ]]; then
    cleanup
fi