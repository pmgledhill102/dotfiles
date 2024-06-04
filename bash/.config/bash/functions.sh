

function test_posh() {
    # Enable Oh My Posh prompt
    eval "$(oh-my-posh init $SH --config 'https://raw.githubusercontent.com/pmgledhill102/dotfiles/dev/ohmyposh/theme.json')"
}

# See <https://medium.com/@guillem.riera/podman-machine-setup-for-x86-64-on-apple-silicon-run-docker-amd64-containers-on-m1-m2-m3-bf02bea38598>
function enable_multiarch_podman() {
    export PODMAN_MACHINE_NAME=${PODMAN_MACHINE_NAME:-podman-machine-default}

    ### Stop all podman machine instances
    ALL_PODMAN_MACHINES=$(podman machine list | awk '{ print $1 }' | tr -d '*' | sed 1d | tr '\n' ' ')
    for PODMAN_MACHINE in ${ALL_PODMAN_MACHINES}; do
        podman machine stop ${PODMAN_MACHINE}
    done

    ### Start the target podman machine
    podman machine start ${PODMAN_MACHINE_NAME}

    ### wait for the podman machine to be running
    PODMAN_MACHINE_STATUS=$(podman machine inspect ${PODMAN_MACHINE_NAME} | jq -r '.[].State')
    while [[ "${PODMAN_MACHINE_STATUS}" != "running" ]]; do
        echo "[Info] Waiting for podman machine '${PODMAN_MACHINE_NAME}' to be running, current status: ${PODMAN_MACHINE_STATUS}..."
        sleep 1
        PODMAN_MACHINE_STATUS=$(podman machine inspect ${PODMAN_MACHINE_NAME} | jq -r '.[].State')
    done

    ### Now that the podman machine is running we can install the package
    podman machine ssh "${PODMAN_MACHINE_NAME}" 'sudo rpm-ostree install qemu-user-static'

    ### Stop the podman machine to apply the changes
    podman machine stop ${PODMAN_MACHINE_NAME}

    ### Start the podman machine again
    podman machine start ${PODMAN_MACHINE_NAME}

    echo "[Info] Done. You can now run multi-architecture images in ${PODMAN_MACHINE_NAME}."
}