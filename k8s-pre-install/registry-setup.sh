#!/bin/bash

# File: registry-setup.sh

## Use below script to setup private registry
## Provide correct IP/Hostname and port in inventory file before running script.

CURRENTDIR=$(cd $(dirname $0); pwd)
KUBESPRAYDIR=${CURRENTDIR}/..
source ${KUBESPRAYDIR}/ski-util.sh

#$$8 $$8 $$8 $$8 ^Helper functions^ 8$$ 8$$ 8$$ 8$S
usage()
{
  _info "Usage: $0 can used setup a privte containerd registry:
   $0 -i REGISTRY_INVENTORY -u REMOTE_USER -p REMOTE_USER_PSWD [--args \"ANSIBLE_ARGS\"]
  Options:
    -i|--inventory <REGISTRY_INVENTORY>   Specify the inventory file host path
    -u|--username  <REMOTE_USER>          Specify the user name to connect to remote hosts. User must have SUDO access
    -p|--password  <REMOTE_USER_PSWD>     Specify the password for REMOTE_USER
    --args         \"ANSIBLE_ARGS\"       Specify ansible extra args E.g. -vv for verbose
    -h|--help                      Show this help message and exit
  "
  exit 1
}


## helper function to execute registry operation

function create_registry()
{
    install_ansible
    setup_password_less_ssh

    _info "Registry will be created for inventory [${INVENTORYFILE}] ..."
    _exec "registry-create" "${PREINSTALLDIR}/registry.yml"

    return ${retVal}
} # End: create_registry


## One can remove the registry created using same inventory
#TODO
function delete_registry() { _info "TBD" 
}
function test_registry() { _info "TBD"
}

# Command lines args parser
function parse_args()
{
    unset USERNAME PASSWORD INVENTORYFILE PROMPT ANSIBLE_ARGS
    PROMPT=1 OPERATION="create"

    ## Commandline argumnet parser
    TEMP=$(getopt -o u:p:i:h --long username:,password:,inventory:,args:,noprompt,delete,test,help -- "$@")
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
        --delete) OPERATION="delete";  shift ;;
        --test) OPERATION="test"; shift ;;
        --noprompt) PROMPT=0; shift ;;
        -h|--help) usage ;;
        --) shift ; break ;;
        *) usage
        esac
    done
} #End: parse_args

main()
{

   [[ "$#" -eq 0 ]] && usage
    parse_args "$@"
    pushd ${KUBESPRAYDIR}
    # Stop if no inventory is provided
    ## Error handling
    [[ -z "${INVENTORYFILE}" || -z "${USERNAME}" || -z "${PASSWORD}" ]] && usage

    [ ! -f ${INVENTORYFILE} ] && _error "Inventory file does not exist" ||
    _info "Inventory file is being used: [${INVENTORYFILE}]"

    # Perform given operation
    if [[ "delete" == ${OPERATION} ]]; then delete_registry
    elif [[ "test" == ${OPERATION} ]]; then test_registry
    else  create_registry
    fi

    popd
    return ${retVal}
}

main "$@"
### End: registry-setup.sh
