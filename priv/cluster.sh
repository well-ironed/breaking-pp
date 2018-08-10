#!/bin/bash

set -e

CMD=${1}
NETWORK=breaking-pp-net
PREFIX=breaking-pp
XARGS="xargs -L1 "
shift

function create_network {
    docker network create --driver=bridge ${NETWORK}
}

function destroy_network {
    if (docker network ls | grep ${PREFIX}); then
      docker network rm ${NETWORK}
    fi
}

function stop_cluster {
    (docker ps -a | grep ${PREFIX} | awk '{ print $1 }' | ${XARGS} docker rm -f) || true
    destroy_network
}

function create_node {
    N=${1}
    SIZE=${2}
    NAME=${PREFIX}-${N}.local
    CLUSTER=""
    for i in $(seq 1 ${SIZE}); do
        CLUSTER+="breaking_pp@${PREFIX}-${i}.local,"
    done

    docker run -d  \
        --network=${NETWORK} \
        --hostname=${NAME} \
        --name=${NAME} \
        -e "BREAKING_PP_CLUSTER=${CLUSTER}" \
        breaking-pp
}

function start_node {
    NAME=${PREFIX}-${1}.local
    docker start ${NAME}
}

function stop_node {
    NAME=${PREFIX}-${1}.local
    docker stop ${NAME}
}

function node_ip {
    N=${1}
    docker inspect \
        -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' \
        ${PREFIX}-${N}.local
}

${CMD} ${@}
