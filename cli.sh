#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0

# If no argument is given -> Downloads the most recently released version of the
# Kubevious CLI binary to your current working directory.
# (e.g. 'install_kubevious.sh')
#
# If one arguments is given -> Downloads the most recently released version of the
# Kubevious CLI binary to the specified directory.
# (e.g. 'install_kubevious.sh  /usr/bin')
#
# Fails if the file already exists.

set -e

# Unset CDPATH to restore default cd behavior. An exported CDPATH can
# cause cd to output the current directory to STDOUT.
unset CDPATH

WHERE=/usr/bin

if [ -n "$1" ]; then
  WHERE="$1"
fi

if ! test -d "$WHERE"; then
  echo "$WHERE does not exist. Create it first."
  exit 1
fi

WHERE=${WHERE%%+(/)}

LATEST_RELEASE_URL=https://api.github.com/repos/kubevious/cli/releases/latest

# Emulates `readlink -f` behavior, as this is not available by default on MacOS
# See: https://stackoverflow.com/questions/1055671/how-can-i-get-the-behavior-of-gnus-readlink-f-on-a-mac
function readlink_f {
  TARGET_FILE=$1

  cd "$(dirname "$TARGET_FILE")"
  TARGET_FILE=$(basename "$TARGET_FILE")

  # Iterate down a (possible) chain of symlinks
  while [ -L "$TARGET_FILE" ]
  do
      TARGET_FILE=$(readlink "$TARGET_FILE")
      cd "$(dirname "$TARGET_FILE")"
      TARGET_FILE=$(readlink "$TARGET_FILE")
  done

  # Compute the canonicalized name by finding the physical path
  # for the directory we're in and appending the target file.
  PHYS_DIR=$(pwd -P)
  RESULT=$PHYS_DIR/$TARGET_FILE
  echo "$RESULT"
}

function find_release_asset_url() {
  local release_info=$1
  local opsys=$2
  local arch=$3

  fileName="kubevious-${opsys}-${arch}"

  release_info=$(echo $release_info | grep -o "browser_download_url\":\s\"\S*${fileName}")
  release_info=${release_info//\"}
  release_info=${release_info/browser_download_url: /}

  echo "${release_info}"
}

WHERE="$(readlink_f "${WHERE}")"

echo "Installing to: ${WHERE}"

OUTPUT_FILE="${WHERE}/kubevious";

if [ -f "${OUTPUT_FILE}" ]; then
  echo "${OUTPUT_FILE} exists. Remove it first."
  exit 1
elif [ -d "${OUTPUT_FILE}" ]; then
  echo "${OUTPUT_FILE} exists and is a directory. Remove it first."
  exit 1
fi

opsys=windows
if [[ "$OSTYPE" == linux* ]]; then
  opsys=linuxstatic
elif [[ "$OSTYPE" == darwin* ]]; then
  opsys=darwin
fi

# Supported values of 'arch': x64, arm64
case $(uname -m) in
x86_64)
    arch=x64
    ;;
arm64|aarch64)
    arch=arm64
    ;;
*)
    arch=x64
    ;;
esac

echo "Release URL: ${LATEST_RELEASE_URL}"

RELEASE_INFO=$(curl -s "$LATEST_RELEASE_URL")
# echo "releases: ${releases}"
# echo "opsys: ${opsys}"
# echo "arch: ${arch}"

if [[ $RELEASE_INFO == *"API rate limit exceeded"* ]]; then
  echo "Github rate-limiter failed the request. Either authenticate or wait a couple of minutes."
  exit 1
fi

ASSET_URL="$(find_release_asset_url "$RELEASE_INFO" "$opsys" "$arch")"

if [[ -z "$ASSET_URL" ]]; then
  echo "ERROR: Could not find release asset for ${opsys}/${arch}."
  exit 1
fi

echo "Downloading asset..."
echo "    Asset URL: ${ASSET_URL}"
echo "    Destination: ${OUTPUT_FILE}"
curl -L "$ASSET_URL" -o ${OUTPUT_FILE}
chmod +x ${OUTPUT_FILE}

kubevious --help

echo "Kubevious installed to ${OUTPUT_FILE}"