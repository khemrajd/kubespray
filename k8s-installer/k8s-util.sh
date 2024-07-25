#!/bin/bash
# k8s-util.sh
# This is utility script having common helper functions
##
RED='\033[0;31m'
NC='\033[0m' # No Color
GREEN='\033[0;32m'
PREINSTALLDIR="${KUBESPRAYDIR}/k8s-pre-install"
POSTINSTALLDIR="${KUBESPRAYDIR}/k8s-post-install"

#Print error and exit
function _error() {
    /bin/echo >&2 -e "\e[101m\e[97m[ERROR]\e[49m\e[39m $@ \n Rectify error and retry. Exiting...";
    exit 1
}

#Print warning
function _warn() {
    /bin/echo >&2 -e "\e[101m\e[97m[WARNING]\e[49m\e[39m $@"
}

# Print info
function _info() {
    /bin/echo -e "\e[104m\e[97m[INFO]\e[49m\e[39m $@"
}

## Execute the provided cluster operation and
## Store inventory backup
function _exec() {
     # Perform given operation
    local comp=${1}
    local yaml=${2}

    cluster_name=$(/usr/bin/sed -n 's/^cluster_name=//p' ${INVENTORYFILE}|xargs)
    logfolder="${KUBESPRAYDIR}/logs/${cluster_name}"
    mkdir -p ${logfolder}  ## create log dir if not present
    local logfile="${logfolder}/${comp}.log"

    invbackup="${logfolder}/${OPERATION}.$(date +%F_%H-%M-%S).ini"
    ## Do not override log file, for add/remove nodes
    if [[ "create" != "${OPERATION}" && "reset" != "${OPERATION}" ]]; then
       echo -e "\n\n\nInventory file '${INVENTORYFILE}' is being used" >> ${logfile}
    else
       echo "Inventory file '${INVENTORYFILE}' is being used" > ${logfile}
    fi

    cp ${INVENTORYFILE} ${invbackup}
    echo "Backup of '${INVENTORYFILE}' has taken as '${invbackup}'" >> ${logfile}
    cat ${INVENTORYFILE} >> ${logfile}

    export ANSIBLE_FORCE_COLOR=true
    cvarfile="${KUBESPRAYDIR}/cvar.yaml"
    playbook_cmd="ansible-playbook -i ${INVENTORYFILE} -b -e @${cvarfile} "
    ANSIBLE_ARGS+=" -e cluster_name=${cluster_name} -e ansible_user=${USERNAME} -e ansible_sudo_pass=${PASSWORD} -v "
    run_cmd="${playbook_cmd} ${eargs} ${ANSIBLE_ARGS} ${yaml}"
    _info "${run_cmd}"

    # unset eargs ANSIBLE_ARGS && return  #=> uncomment to debug ansible command without actual execution
    #(
       set -o pipefail
       ${run_cmd} | tee -a ${logfile}
       retVal=${PIPESTATUS}
       unset eargs ANSIBLE_ARGS
       set +o pipefail
    #)
    [[ ${retVal} -eq 0 ]] &&
        _info "Success: [${GREEN}${comp}${NC}] completed" ||
        _error "Failed: [${RED}${comp}${NC}] failed with PIPESTATUS ${retVal}"

    return ${retVal}
} #End: _exec

# Get ansible/k8s version info
function get_version_info(){
    cvarfile="${KUBESPRAYDIR}/cvar.yaml"
    unset  K8S_VERSION ANSB_VERSION
    K8S_VERSION=$(/usr/bin/sed -n 's/^k8s_version://p' ${cvarfile}|xargs)
    ANSB_VERSION=$(/usr/bin/sed -n 's/^ansible_version://p' ${cvarfile}|xargs)
} #End: get_version_info

# Playbooks can run only with ansible presence. 
function install_ansible(){
    get_version_info

    offline_files="${PREINSTALLDIR}/k8s-${K8S_VERSION}-offline-files"
    ansi_pkg_dir="${offline_files}/ansible"
    venvdir=kubespray-venv
    pip_local_install="python3 -m pip install --upgrade --no-index --find-links=${ansi_pkg_dir} --ignore-installed"
    export PATH=${PATH}:/usr/local/bin

    # Check if python3 is installed
    if [ ! /usr/bin/which python3 > /dev/null 2>&1 ]; then
        _error "Could not find python3"
    fi

    if ! /usr/bin/grep -q "sshpass" <<< $(rpm -qa sshpass); then
        /usr/bin/echo "${PASSWORD}" | /usr/bin/sudo -S /usr/bin/dnf \
            localinstall -yq ${ansi_pkg_dir}/sshpass-1.09-4.el8.x86_64.rpm
    fi

    # Install virtualenv if not present
    if ! /usr/bin/which virtualenv > /dev/null 2>&1; then
        /usr/bin/echo "${PASSWORD}" | /usr/bin/sudo -S ${pip_local_install} virtualenv
    fi

    _info "Creating virtual environment into [./${venvdir}]..."
    virtualenv --python=$(/usr/bin/which python3) ${venvdir}
    _info "Activating virtual environment from [./${venvdir}]..."
    source ${venvdir}/bin/activate

    ## Install ansible only if not present in virtual env
    if [ ! -x ${venvdir}/bin/ansible ]; then
        _info "Installing k8s requirement from [${KUBESPRAYDIR}/requirements.txt]"
        ${pip_local_install} -r ${KUBESPRAYDIR}/requirements.txt
    fi
    #we should have ${venvdir}/bin/ansible installed now
    [[ ! -x ${venvdir}/bin/ansible ]] && _error "Failed to install ansible[$ANSB_VERSION]"

} # End install_ansible

# Ansible need password-less communicaiton between ansible node and cluster nodes
function setup_password_less_ssh(){
    #Generate key if not present
    [[ ! -f ~/.ssh/id_rsa ]] && /usr/bin/ssh-keygen -q -t rsa -b 2048 -N '' -f ~/.ssh/id_rsa <<< n

    IPS=($(ansible-inventory --list -i ${INVENTORYFILE} | grep -w ansible_host | awk -F'"' '{print $4}'))
    ANSIBLE_ARGS+=" --forks ${#IPS[@]} "

    [[ ${#IPS[@]} -eq 0 ]] &&
        _error "Unable to parse the host from inventory file ${INVENTORYFILE}.
            Look at the sample file placed at inventory/sample/inventory.ini\n" ||
        _info "Node list parsed from inventory ${INVENTORYFILE} is\n ${IPS[@]}"

    # loop thrugh host for enabling passwordless ssh
    for IP in ${IPS[@]}; do
        /usr/bin/sshpass -p ${PASSWORD} ssh-copy-id -o StrictHostKeyChecking=no ${USERNAME}@${IP} > /dev/null 2>&1
        [ $? -ne 0 ] && _error "Failed to copy ssh-copy-id. Check the username/password or host connectivity"
        _info "Successfully copied ssh-copy-id for node ${IP}"
    done
} #End: setup_password_less_ssh

# End: k8s-util.sh
