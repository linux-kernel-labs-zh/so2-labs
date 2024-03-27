#!/bin/bash

if [[ $(id -u) != "0" ]]; then
   echo "Please run as root (or use sudo)"
   exit 1 
fi

cd "$(dirname "$0")" || exit 1

#=============================================================================
#================================= CONSTANTS =================================
#=============================================================================

RED='\033[0;31m'
NC='\033[0m'

DEFAULT_IMAGE_NAME="so2/so2-assignments"
DEFAULT_TAG='latest'
DEFAULT_REGISTRY='gitlab.cs.pub.ro:5050'
SO2_WORKSPACE="/linux/tools/labs"
SO2_VOLUME="SO2_DOCKER_VOLUME"
#=============================================================================
#=================================== UTILS ===================================
#=============================================================================

LOG_INFO() {
    echo -e "[$(date +%FT%T)] [INFO] $1"
}

LOG_FATAL() {
    echo -e "[$(date +%FT%T)] [${RED}FATAL${NC}] $1"
    exit 1
}

#=============================================================================
#=============================================================================
#=============================================================================

print_help() {
    echo "Usage:"
    echo "local.sh docker interactive [--privileged]"
    echo ""
    echo "      --privileged - run a privileged container. This allows the use of KVM (if available)"
    echo "      --allow-gui - run the docker such that it can open GUI apps"
    echo ""
}

docker_interactive() {
    local full_image_name="${DEFAULT_REGISTRY}/${DEFAULT_IMAGE_NAME}:${DEFAULT_TAG}"
    local executable="/bin/bash"
    local registry=${DEFAULT_REGISTRY}

    while [[ $# -gt 0 ]]; do
        case $1 in
        --privileged)
            privileged=--privileged
            ;;
        --allow-gui)
            allow_gui=true
            ;;
        *)
            print_help
            exit 1
        esac
        shift
    done

    if [[ $(docker images -q $full_image_name 2> /dev/null) == "" ]]; then
        docker pull $full_image_name
    fi

    if ! docker volume inspect $SO2_VOLUME >/dev/null 2>&1; then
        echo "Volume $SO2_VOLUME does not exist."
        echo "Creating it"
	docker volume create $SO2_VOLUME
	local vol_mount=$(docker inspect $SO2_VOLUME | grep -i mountpoin | cut -d : -f2 | cut -d, -f1)
	chmod 777 -R $vol_mount
    fi

    echo "The /linux directory is made persistent within the $SO2_VOLUME:"
    docker inspect $SO2_VOLUME

    if $allow_gui; then
	
	# TODO: remove this after you change sdl to gtk in qemu-runqemu.sh
 	docker run $privileged --rm -it --cap-add=NET_ADMIN --device /dev/net/tun:/dev/net/tun \
        -v $SO2_VOLUME:/linux \
        --workdir "$SO2_WORKSPACE" \
        "$full_image_name" sed "s+\${QEMU_DISPLAY:-\"sdl\"+\${QEMU_DISPLAY:-\"gtk\"+g" -i /linux/tools/labs/qemu/run-qemu.sh

	# wsl
	if cat /proc/version | grep -i microsoft &> /dev/null ; then
		export DISPLAY="$(ip r show default | awk '{print $3}'):0.0"
	fi

	if [[ $DISPLAY == "" ]]; then
		echo "Error: Something unexpected happend. The environment var DISPLAY is not set. Consider setting it with"
		echo -e "\texport DISPLAY=<dispaly>"
		exit 1
	fi

	local xauth_var=$(echo $(xauth info | grep Auth | cut -d: -f2))
        docker run --privileged --rm -it \
        --net=host --env="DISPLAY" --volume="${xauth_var}:/root/.Xauthority:rw" \
        -v $SO2_VOLUME:/linux \
        --workdir "$SO2_WORKSPACE" \
        "$full_image_name" "$executable"
    else
        docker run $privileged --rm -it --cap-add=NET_ADMIN --device /dev/net/tun:/dev/net/tun \
        -v $SO2_VOLUME:/linux \
        --workdir "$SO2_WORKSPACE" \
        "$full_image_name" "$executable"
    fi

}

docker_main() {
    if [ "$1" = "interactive" ] ; then
        shift
        docker_interactive "$@"
    fi
}


if [ "$1" = "docker" ] ; then
    shift
    docker_main "$@"
elif [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    print_help
else
    print_help
fi
