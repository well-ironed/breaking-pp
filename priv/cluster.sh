#!/bin/bash

set -e

CMD=${1}
NETWORK=breaking-pp-net
PREFIX=breaking-pp
shift

function create_network {
    docker network create --driver=bridge ${NETWORK}
}

function destroy_network {
    docker network rm ${NETWORK}
}

function stop_cluster {
    docker ps -a | grep ${PREFIX} | awk '{ print $1 }' | xargs docker rm -f
    destroy_network
}

function start_node {
    N=${1}
    SIZE=${2}
    NAME=${PREFIX}-${N}.local
    CLUSTER=""
    for i in $(seq 1 ${SIZE}); do
        CLUSTER+="breaking_pp@${PREFIX}-${i}.local,"
    done

    docker run -d -p ${N}4000:4000 \
        --network=${NETWORK} \
        --hostname=${NAME} \
        --name=${NAME} \
        -e "BREAKING_PP_CLUSTER=${CLUSTER}" \
        breaking-pp
}

${CMD} ${@}
