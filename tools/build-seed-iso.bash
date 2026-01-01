#!/usr/bin/env bash
set -euo pipefail

## spell-checker:ignore ugreen localds nullglob pubfile

########################
# CONFIGURABLE SETTINGS
########################

# VM identity
VM_HOSTNAME="${VM_HOSTNAME:-debian-cloud}"
INSTANCE_ID="${INSTANCE_ID:-${VM_HOSTNAME}-001}"

# Paths (relative to this script's directory)
BUILD_DIR="../#build"
SRC_DIR="../src"
KEYS_DIR="${SRC_DIR}/${KEYS_DIR:-ssh-public-keys}"
DATA_DIR="${SRC_DIR}/cloud-init-data"

USER_TEMPLATE_FILE="${DATA_DIR}/${USER_TEMPLATE_FILE:-user-data.template}"

USER_DATA="${BUILD_DIR}/data/${USER_DATA:-user-data}"
META_DATA="${BUILD_DIR}/data/${META_DATA:-meta-data}"

NETWORK_CONFIG="../${NETWORK_CONFIG:-network-config}"

# Output ISO name
SEED_ISO_NAME="${BUILD_DIR}/iso/${SEED_ISO_NAME:-seed-${VM_HOSTNAME}.iso}"

# Where your UGREEN NAS is mounted in WSL
# e.g. if \\UGREEN\ISOs is mounted as /mnt/ugreen/ISOs:
NAS_MOUNT="${NAS_MOUNT:-/mnt/ugreen}"
NAS_SUBDIR="${NAS_SUBDIR:-ISOs/cloud-init/debian}"
DEST_DIR="${NAS_MOUNT}/${NAS_SUBDIR}"

########################
# FUNCTIONS
########################

err() {
    echo "ERROR: $*" >&2
    exit 1
}

check_deps() {
    command -v cloud-localds >/dev/null 2>&1 || err "cloud-localds (cloud-image-utils) not found. Install with: \`sudo apt install cloud-image-utils\`"
}

generate_user_data() {
    # create build path, if needed
    mkdir -p "$(dirname "${USER_DATA}")"

    [ -f "${USER_TEMPLATE_FILE}" ] || err "Template file '${USER_TEMPLATE_FILE}' not found"
    [ -d "${KEYS_DIR}" ] || err "Keys directory '${KEYS_DIR}' not found"

    local any_key=false
    # We will stream template → replace placeholder line with keys
    {
    while IFS= read -r line; do
        if [[ "$line" =~ ^[[:space:]]*"[ AUTHORIZED_SSH_PUBLIC_KEYS ]" ]]; then
            # Extract leading whitespace
            leading_whitespace="${line%%[![:space:]]*}"
            # Inject each .pub file as a YAML list item with preserved indentation
            shopt -s nullglob
            for pubfile in "${KEYS_DIR}"/*.pub; do
                any_key=true
                key="$(<"$pubfile")"
                printf '%s- %s\n' "$leading_whitespace" "$key"
            done
            shopt -u nullglob
            if [ "${any_key}" = false ]; then
                err "No .pub files found in ${KEYS_DIR}"
            fi
        else
            echo "$line"
        fi
        done < "${USER_TEMPLATE_FILE}"
    } > "${USER_DATA}"
    echo "Generated '${USER_DATA}' with keys from '${KEYS_DIR}/'"
}

generate_meta_data() {
  cat > "${META_DATA}" <<EOF
instance-id: ${INSTANCE_ID}
local-hostname: ${VM_HOSTNAME}
EOF
    echo "Wrote ${META_DATA}"
}

build_seed_iso() {
    local iso="${SEED_ISO_NAME}"
    # create build path, if needed
    mkdir -p "$(dirname "${iso}")"

    if [ -f "${NETWORK_CONFIG}" ]; then
        echo "Building seed ISO with network-config: ${NETWORK_CONFIG}"
        cloud-localds -N "${NETWORK_CONFIG}" "${iso}" "${USER_DATA}" "${META_DATA}"
    else
        echo "Building seed ISO without network-config"
        cloud-localds "${iso}" "${USER_DATA}" "${META_DATA}"
    fi

    echo "Created ${iso}"
}

copy_to_nas() {
    if [ ! -d "${NAS_MOUNT}" ]; then
        echo "NAS mount ${NAS_MOUNT} does not exist. Skipping copy."
        return 0
    fi

    mkdir -p "${DEST_DIR}"
    cp "${SEED_ISO_NAME}" "${DEST_DIR}/"
    echo "Copied ${SEED_ISO_NAME} to ${DEST_DIR}/"
}

########################
# MAIN
########################

cd "$(dirname "$0")"

check_deps
generate_user_data
generate_meta_data
build_seed_iso
## copy_to_nas

echo "Done."
echo "Seed ISO: $(pwd)/${SEED_ISO_NAME}"
