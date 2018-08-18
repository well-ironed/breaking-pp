#!/bin/bash
set -e

cmd=${1}
network=breaking-pp-net
prefix=breaking-pp
iptables_img="vimagick/iptables:latest"
iptables_prefix="brk-pp-"
xargs="xargs -L1 "
subnet=172.18.0

function help {
  echo "
  $0 create_network
    Creates Docker network used to connect test containers together.

  $0 destroy_network
    Removes Docker network.

  $0 stop_cluster
    Stops the whole cluster.

  $0 create_node <NODE_ID> <CLUSTER_SIZE>
    Creates a node with given id (integer) in a cluster of given size.

  $0 start_node <NODE_ID>
    Starts node with given id.

  $0 stop_node <NODE_ID>
    Stops node with given id.

  $0 split <NODE_ID_1> <NODE_ID_2>
    Block all traffic between two containers.
    Traffic between all other containers remains unblocked.

  $0 join <NODE_ID_1> <NODE_ID_2>
    Allow all traffic between two containers,
    clearing any blocks previously established between them.
    All other blocks remain in place.

  $0 reset_splits
    Clear all managed blocks in the cluster.

  $0 node_ip <NODE_ID>
    Get the IP address of container <NODE_ID>
  " >&2
}

function create_network {
    docker network create --driver=bridge \
        --subnet="${subnet}.0/24" \
        --gateway="${subnet}.100" ${network}
}

function destroy_network {
    if (docker network ls | grep ${prefix}); then
      docker network rm ${network}
    fi
}

function stop_cluster {
    (docker ps -a | grep ${prefix} | awk '{ print $1 }' | ${xargs} docker rm -f) || true
    destroy_network
}

function create_node {
    n=${1}
    size=${2}
    name=$(_node_name $n)

    docker run -d  \
        --network=${network} \
        --ip="${subnet}.${n}" \
        --hostname=${name} \
        --name=${name} \
        -e "BREAKING_PP_CLUSTER=$(_cluster_nodes $size)" \
        -e "TRACKER=${TRACKER}" \
        breaking-pp
}

function start_node {
    docker start $(_node_name ${1})
}

function stop_node {
    docker stop $(_node_name ${1})
}

function split {
  n1=${1};
  n2=${2};
  n1_ip=$(node_ip ${n1})
  n2_ip=$(node_ip ${n2})
  chain=$(_hash_nodes ${n1} ${n2})
  _iptables -N ${chain} \
    && _iptables -I FORWARD -s ${n1_ip} -d ${n2_ip} -j ${chain} \
    && _iptables -I FORWARD -s ${n2_ip} -d ${n1_ip} -j ${chain} \
    && _iptables -I ${chain} -s ${n1_ip} -d ${n2_ip} -j DROP \
    && _iptables -I ${chain} -s ${n2_ip} -d ${n1_ip} -j DROP
}

function join {
  n1=${1};
  n2=${2};
  n1_ip=$(node_ip ${n1})
  n2_ip=$(node_ip ${n2})
  chain=$(_hash_nodes ${n1} ${n2})
  for rule_number in $(_rule_numbers_for "${chain}")
  do _iptables -D FORWARD ${rule_number}; done
  _iptables -F ${chain}
  _iptables -X ${chain}
}

function reset_splits {
  for rule_number in $(_rule_numbers_for "${iptables_prefix}")
  do _iptables -D FORWARD ${rule_number} ; done

  for chain in $(_iptables -L | grep "${iptables_prefix}" | awk '{print $2}')
  do _iptables -F ${chain}
     _iptables -X ${chain}
  done
}


function node_ip {
    docker inspect \
        -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' \
        ${prefix}-${1}.local
}

function _cluster_nodes {
    cluster=""
    for i in $(seq 1 ${size}); do
        cluster+="breaking_pp@${prefix}-${i}.local,"
    done
    echo "${cluster}"
}

function _node_name {
    echo "${prefix}-${1}.local"
}

function _rule_numbers_for {
  search_for="${1}"
  _iptables --line-numbers -L FORWARD \
    | grep "${search_for}"  \
    | awk '{print $1}' \
    | sort -rn
}

function _hash_nodes {
  ## Given 2 node names, generate a deterministic ID for the chain
  ## that links them
  ord=$(/bin/echo -en "${1}\n${2}\n" | sort)
  id=$(echo -n "${ord}" | md5sum | cut -c -20)
  echo "${iptables_prefix}${id}"
}

function _iptables {
  ## Call dockerized iptables with args
  (docker run --rm --net=host --privileged=true ${iptables_img} \
	  iptables "$@") | tail -n+2 || true
}

shift
${cmd} ${@}
