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

log_message() {
    local message="$1"
    echo "$(date +'%Y-%m-%d %H:%M:%S') - ${message}"
}

exit_error() {
    local message="$1"
    echo "ERROR: ${message}"
    exit 1
}

wait_port() {
    local port="$1"
    local waited=0
    local max_wait=60
    local wait_increment=2

    # Wait until curl exits with a zero return code meaning it got some http status code response (200, 404, etc..)
    until curl -s "localhost:${port}" 2>&1 > /dev/null; do
        if [[ $waited -gt $max_wait ]]; then
            exit_error "localhost:$port was not ready after ${max_wait} seconds"
        fi
        sleep $wait_increment
        waited=$((waited+wait_increment))
    done
}

########################################
# Script starts here
########################################

builder_uri=${IMAGE_URI:-localhost:5041/amazonlinux-builder:latest}
token="" # can be empty or set to a valid token and is used for downloading pack and jam binaries

repo::prepare

tools::install "${token}"

log_message "STATE: Testing builder_uri: ${builder_uri}"

if [[ ! -d test ]]; then
    mkdir test
fi

cd test

if [[ ! -d samples ]]; then
  git clone https://github.com/paketo-buildpacks/samples
fi

cd samples

# --------------------------------------
export SAMPLE=samples-go-no-imports
log_message "STATE: Building ${SAMPLE} with builder: ${builder_uri}"

pack build ${SAMPLE} --path go/no-imports --pull-policy if-not-present \
    --builder ${builder_uri}

pack inspect ${SAMPLE}

docker run --detach --rm --name ${SAMPLE} --env PORT=8080 --publish 8080:8080 ${SAMPLE}
wait_port 8080
curl -s -w "%{http_code}" http://localhost:8080 -o /dev/null | grep -q '^200$' || exit_error "Error running app for ${SAMPLE}"
docker kill ${SAMPLE}

# --------------------------------------
export SAMPLE=sample-procfile
mkdir -p empty-app
builder_uri="${builder_uri}-${size}"
log_message "STATE: Building ${SAMPLE} with builder: ${builder_uri}"

pack build ${SAMPLE} --path empty-app --pull-policy if-not-present \
    --env BP_PROCFILE_DEFAULT_PROCESS="echo hello world" \
    --builder ${builder_uri}

pack inspect ${SAMPLE}

docker run --rm ${SAMPLE} | grep -q "hello world" || exit_error "Error running app for ${SAMPLE}"
