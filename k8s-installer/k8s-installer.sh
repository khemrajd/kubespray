#!/bin/bash
# File: k8s-installer.sh

## Use below script to automate the kubernetes cluster operations.
# Operation could be create cluster, reset cluster.
## Provide correct IP/Hostnames in inventory file before running script.

KUBESPRAYDIR=$(cd $(dirname $0); pwd)
source ${KUBESPRAYDIR}/ski-util.sh

#$$8 $$8 $$8 $$8 ^Helper functions^ 8$$ 8$$ 8$$ 8$S
#User guide
function usage() {
  _info "Usage: $0 can used create or reset the k8s cluster:
  $0 -i <INVENTORY_RELATIVE_PATH -u REMOTE_USER -p REMOTE_USER_PSWD [CLUSTER_OPERATION] [--args \"ANSIBLE_ARGS\"] [--noprompt]
  CLUSTER_OPERATION is optional and can be any of the following (No opration implies 'cluster create'):
    (--reset | --addcontrollernode | --addworkernode | --removenode node_to_remove)
  Options:
    -i|--inventory <INVENTORY_RELATIVE_PATH>  Inventory file must be in $PWD/inventory/sample folder
    -u|--username  <REMOTE_USER>          Specify the user name to connect to remote hosts. User must have SUDO access
    -p|--paswword  <REMOTE_USER_PSWD>     Specify the password for REMOTE_USER
    --noprompt	   Do not wait for user confirmation. If provided tool proceeds without user confirmation for given cluster operation
    --addcontrollernode            Add controller node to the existing cluster
    --addworkernode                Add worker node to the existing cluster
    --removenode <node_to_remove>  Remove controller/worker node from the existing cluster
    --reset                        Delete last successfully created cluster
    --args         \"ANSIBLE_ARGS\" Ansible command line options can be passed E.g. -vv for verbose
    -h|--help                      Show this help message and exit
  "
  exit 1
}

# Perform cluster creation pre requisites tasks 
function preinstall(){
    ip_pool_range=$(grep "^ip_pool_range=" ${INVENTORYFILE} | awk -F"=" '{print $2}' | tr -d "'" | tr -d "\r")
    [[ -z ${ip_pool_range} ]] &&
        _warn "No [ip_pool_range] is provided. MetalLB will not be installed for cluster ${cluster_name}" ||
        _info "Provided ip_pool_range=[${ip_pool_range}]";

    _exec "preinstall" "${PREINSTALLDIR}/preinstall.yml"
    return ${retVal}
}

function postinstall(){
    _exec "postinstall" "${POSTINSTALLDIR}/postinstall.yaml"
    return ${retVal}
}

# New cluster creation 
function create_cluster() {
    [[ (-s cluster-list.txt) &&	## if cluster-list.txt is exist
         (${cluster_name} == $(grep "^${cluster_name}" cluster-list.txt | awk -F":" '{print $1}' | xargs)) ]] &&
         _error "Cluster entry is present is cluster-list.txt. Try again with different cluster name."

    #Copy binaries
    eargs=" -e prechecks=true " && preinstall

    ## Go ahead and create cluster
    _info "Cluster will be created for inventory [${INVENTORYFILE}] ..."
    _exec "cluster" "${KUBESPRAYDIR}/cluster.yml"
    postinstall && _info "Success: ${GREEN}cluster created${NC}"

    return ${retVal}
}


# Add controller node to the cluster
function add_controller() {
    ## Go ahead and add controller node to the cluster
    _info "Controller node is being added to cluster for the inventory [${INVENTORYFILE}] ..." && preinstall
    eargs=" --limit=etcd,kube_controller_nodes -e ignore_assert_errors=yes "
    _exec "add-controller" "${KUBESPRAYDIR}/cluster.yml"
    postinstall && _info "Success: ${GREEN}Controller node added${NC} to cluster"
    return ${retVal}
}

# Add worker node to the cluster
function add_worker() {
    ## Go ahead and add worker node to the cluster
    _info "Worker node is being added to cluster for the inventory [${INVENTORYFILE}] ..." && preinstall
    _exec "add-worker" "${KUBESPRAYDIR}/scale.yml"
    postinstall && _info "Success: ${GREEN}worker node added${NC} to cluster"
    return ${retVal}
}

#Delete cluster
function reset_cluster() {
    [[ ${NOPROMPT} -eq 1 ]] && eargs=" -e reset_confirmation=yes "

    _info "Cluster will be \e[101m\e[97mreset/deleted\e[49m\e[39m for the inventory [${INVENTORYFILE}] ..."
    _exec "reset" "${KUBESPRAYDIR}/reset.yml" &&
    _exec "postreset" "${POSTINSTALLDIR}/postreset.yaml"

    [[ ${retVal} -eq 0 ]] && _info "Success: cluster \e[101m\e[97mDeleted/Removed\e[49m\e[39m"
    return ${retVal}
}

# Remove cluster node (excpet primary controller) out of cluster
function remove_node() {
    [[ ${NOPROMPT} -eq 1 ]] && eargs=" -e skip_confirmation=true"

    ## Go ahead and remove node from the cluster
    _info "Node [${node_to_remove}] is being removed from cluster"
    eargs+=" -e node=${node_to_remove}"
    _exec "remove-node" "${KUBESPRAYDIR}/remove-node.yml"

    [[ ${retVal} -eq 0 ]] && _info "Success: ${GREEN}node [${node_to_remove}] removed${NC}"
    return ${retVal}
}

# Remove primary controller node out of cluster
function remove_primary_controller() {
    [[ ${NOPROMPT} -eq 1 ]] && eargs=" -e skip_confirmation=true"
    ## Go ahead and remove node from the cluster
    _info "Primary controller [${node_to_remove}] is being removed from cluster"
    eargs+=" -e node=${node_to_remove}"
    _exec "removeprimarycontroller" "${KUBESPRAYDIR}/removeprimarycontroller.yml"

    [[ ${retVal} -eq 0 ]] && _info "Success: ${GREEN}primary controller removed${NC}"
    return ${retVal}
}

## Commandline argumnet parser
function parse_args() {
    unset USERNAME PASSWORD INVENTORYFILE NOPROMPT ANSIBLE_ARGS OPERATION node_to_remove
    NOPROMPT=0 OPERATION="create"

    TEMP=$(getopt -o u:p:i:h --long username:,password:,inventory:,args:,reset,noprompt,addcontrollernode,addworkernode,removenode:,removeprimarycontroller:,help -- "$@")
    exitCode=$?
    [[ $exitCode -ne 0 ]] && usage
    eval set -- "$TEMP"

    # extract options and their arguments into variables.
    while true ; do
        case "$1" in
        -i|--inventory)     INVENTORYFILE=$2; shift 2 ;;
        -u|--username)      USERNAME=$2; shift 2 ;;
        -p|--password)      PASSWORD=$2; shift 2 ;;
        --args)             ANSIBLE_ARGS=$2; shift 2;;
        --noprompt)         NOPROMPT=1; shift ;;
        --reset)            OPERATION="reset"; shift ;;
        --addcontrollernode)OPERATION="addcontrollernode"; shift ;;
        --addworkernode)    OPERATION="addworkernode"; shift ;;
        --removenode)       OPERATION="removenode"; node_to_remove=$2; shift 2;;
        --removeprimarycontroller) OPERATION="removeprimarycontroller"; node_to_remove=$2; shift 2;;
        -h|--help) usage ;;
        --) shift ; break ;;
        *) usage

        esac
    done

    [[ -z "${USERNAME}" || -z "${PASSWORD}" || -z "${INVENTORYFILE}" ]] && \
        _warn "Username or password or inventory can't be empty" && usage
}

## Main function to perform cluster operations
function main() {
    parse_args "$@"
    pushd ${KUBESPRAYDIR}
    # Stop if no inventory is provided
    [ ! -f ${INVENTORYFILE} ] && _error "Inventory file does not exist"
    _info "Inventory file is being used: [${INVENTORYFILE}]"

    cluster_name=$(/usr/bin/sed -n 's/^cluster_name=//p' ${INVENTORYFILE})
    [[ -z ${cluster_name} ]] && _error "Cluster name can not be empty"

    install_ansible
    setup_password_less_ssh

    if   [ "${OPERATION}" == "create" ];                    then create_cluster
    elif [ "${OPERATION}" == "addcontrollernode" ];         then add_controller
    elif [ "${OPERATION}" == "addworkernode" ];             then add_worker
    elif [ "${OPERATION}" == "reset" ];                     then reset_cluster
    elif [ "${OPERATION}" == "removenode" ];                then remove_node
    elif [ "${OPERATION}" == "removeprimarycontroller" ];   then remove_primary_controller
    else _error "Invalid operation"
    fi

    popd
    return ${retVal}
}

main "$@"

### End: k8s-installer.sh

