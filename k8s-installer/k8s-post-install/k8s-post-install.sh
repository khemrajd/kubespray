#!/bin/bash
# File: k8s-post-install.sh

CURRENTDIR=$(cd $(dirname $0); pwd)
KUBESPRAYDIR=${CURRENTDIR}/..
declare comps=()

source ${KUBESPRAYDIR}/k8s-util.sh

#$$8 $$8 $$8 $$8 ^Helper functions^ 8$$ 8$$ 8$$ 8$$

# User guide
function usage() {
  _info "Usage: $0 is used to configure components like registry/metallb for ready cluster
  $0 -i INVENTORY_FILE_PATH -u REMOTE_USER -p REMOTE_USER_PSWD --registry|--metallb [--args \"ANSIBLE_ARGS\"]
  Options:
    -i|--inventory <INVENTORY_FILE_PATH>  Specify the inventory file host path
    -u|--username  <REMOTE_USER>          Specify the user name to connect to remote hosts. User must have SUDO access
    -p|--paswword  <REMOTE_USER_PSWD>     Specify the password for REMOTE_USER
    --args         \"ANSIBLE_ARGS\"       For any operation, ansible command line options can be passed E.g. -vv for verbose
    --registry				  Configure registry
    --metallb 		  		  Configure metalLB
    -h|--help                             Show this help message and exit
  "
  exit 1
} #End: usage

function setup_registry(){
    _info "Configuring registry"
   registry_endpoint=$(/usr/bin/sed -n 's/^registry_endpoint=//p' ${INVENTORYFILE}| xargs | tr -d "'" | tr -d "\"" | tr -d "\r")
    [[ -z ${registry_endpoint} ]] &&
        _error "No registry_endpoint is provided" ||
        _info "Provided registry_endpoint=[${registry_endpoint}]\n";
    eargs=" --tags=containerd "
    _exec "registry-setup" "${KUBESPRAYDIR}/cluster.yml"
    ## Test configured registry
    eargs=" -e registry_test=true "
    _exec "registry-test" "${PREINSTALLDIR}/registry-test.yml"
    return ${retVal}
}

function setup_metallb(){
    _info "Configuring MetalLB"
    ip_pool_range=$(/usr/bin/sed -n 's/^ip_pool_range=//p' ${INVENTORYFILE}| xargs | tr -d "\r")
    [[ -z ${ip_pool_range} ]] &&
        _error "No ip_pool_range is provided for cluster ${cluster_name}" ||
        _info "Provided ip_pool_range=[${ip_pool_range}]\n";

    eargs=" --tags=metallb"
    _exec "metallb" "${KUBESPRAYDIR}/cluster.yml"
}

function setup_calico(){
    _info "Reconfiguring calico"
    _exec "calicofix" "${POSTINSTALLDIR}/postinstall.yaml"
}

# Command lines args parser
function parse_args(){
    unset USERNAME PASSWORD INVENTORYFILE ANSIBLE_ARGS
    ## Commandline argumnet parser
    TEMP=$(getopt -o u:p:i:h --long username:,password:,inventory:,args:,registry,metallb,calico,help -- "$@")
    exitCode=$?
    [[ $exitCode -ne 0 ]] && usage

    eval set -- "$TEMP"
    # extract options and their arguments into variables.
    while true ; do
        case "$1" in
        -i|--inventory) INVENTORYFILE=$2; shift 2 ;;
        -u|--username) 	USERNAME=$2; shift 2 ;;
        -p|--password) 	PASSWORD=$2; shift 2 ;;
        --args) ANSIBLE_ARGS=$2; shift 2;;
	--registry) comps+=("registry"); shift 1;;
	--metallb) comps+=("metallb"); shift 1;;
	--calico) comps+=("calico"); shift 1;;
        -h|--help) usage ;;
        --) shift ; break ;;
        *) usage
        esac
    done

    [[ -z "${USERNAME}" || -z "${PASSWORD}" || -z "${INVENTORYFILE}" ]] && \
        _warn "Username or password or inventory can't be empty" && usage

    [[ ${#comps[@]} -eq 0 ]] && _warn "No component found, provide at least one and retry..." && usage
} #End: parse_args

# Main function to configure componenets like registry,metallb
function main(){
    [[ "$#" -eq 0 ]] && usage
    parse_args "$@"
    pushd ${KUBESPRAYDIR}
    install_ansible
    setup_password_less_ssh

    for comp in ${comps[@]}; do
        setup_${comp}
    done
    popd
} #End: main

main "$@"

# End: k8s-post-install.sh

