#!/bin/bash

#$$$$$$$$ Variable section $$$$$$$$
logfile=".cluster.log"
credfile="secret.yml"
cvarfile="custom_vars.yml"
vaultpassfile=".vaultpass"
vaultpass="ss(8k^8s@"
OFFLINE_PKG_DIR="offline_files/local"

#$$$$$$$$ Helper functions $$$$$$$$
usage()
{
  _info "Usage: $0 -u REMOTE_USER -p REMOTE_USER_PSWD [ -i INVENTORY_FILE_PATH ] [--prompt]
  Options:
    -u|--username  <REMOTE_USER>          Specify the user name to connect to remote hosts. User must have SUDO access
    -p|--paswword  <REMOTE_USER_PSWD>     Specify the password for REMOTE_USER
    -i|--inventory <INVENTORY_FILE_PATH>  Specify the inventory file host path		
    --prompt				  If provided tool asks confirmation on cluster creation, else cluster creation will continue
    					  --prompt is useful to verify/customize cluster parameter if needed
  "
  exit 2
}

_error() { echo -e "$@ \nExiting..."; exit 2; }

_info() { echo -e "\n$@"; }

## install the kubespray ansible required packages
install_pip_packages()
{
    _info "Installing kubespray pre-requisites"

    # 1. Install ansible rpm dependency
    TMPRPMDIR=".rpm_tmp"
    cp -r ${OFFLINE_PKG_DIR}/ansible_rpms ${TMPRPMDIR}
    echo "${PASSWORD}" |sudo -S yum install -y ${TMPRPMDIR}/*.rpm
    rm -rf ${TMPRPMDIR}
    # 2. Install ansible pip dependency
    sudo pip install --no-index --find-links=${OFFLINE_PKG_DIR}/ansible_kube_pippkgs -r requirements.txt

    # 3. Install ansible collection dependency
    ansible-galaxy collection install ${OFFLINE_PKG_DIR}/ansible_collections_files/community/community-docker-1.6.1.tar.gz

    _info "kubespray pre-requisites installed"
}

## copy private key to node to enable passwoedless ssh
enable_ssh()
{
	#Generate key if not present
	if [ ! -f ~/.ssh/id_rsa ] ; then
		ssh-keygen -q -t rsa -b 2048 -N '' -f ~/.ssh/id_rsa <<< n
	fi
	IPS=$(ansible-inventory --list -i ${INVENTORYFILE} | grep -w ansible_host | cut -d ":" -f 2 |tr -d , | tr -d \")

	if [ ${#IPS[@]} -eq 0 ]; then 
		 _error "Unable to parse the host from inventory file ${INVENTORYFILE}.
   	 Look at the sample file placed at inventory/sample/inventory.ini\n"
	else
    	_info "\nNode list parsed from inventory ${INVENTORYFILE} is\n ${IPS[@]}"
	fi

	# loop thrugh host for enabling passwordless ssh
	for IP in ${IPS[@]}; do
  		sshpass -p ${PASSWORD} ssh-copy-id -o StrictHostKeyChecking=no ${USERNAME}@${IP} > /dev/null 2>&1
  		[ $? -ne 0 ] && _error "Failed to copy ssh-copy-id. Check the username/password or host connectivity"
  		_info "Successfully copied ssh-copy-id for node ${IP}"
	done
}

## generate vault to decrypt credentials
generate_vault()
{
	echo ${vaultpass} > ${vaultpassfile}
	echo "ansible_sudo_pass: ${PASSWORD}" > ${credfile}
	ansible-vault encrypt --vault-password-file=${vaultpassfile} ${credfile}
}

create_cluster()
{
	grep "ansible_user=${USERNAME}" ${INVENTORYFILE} -q
	[ $? -ne 0 ] && echo -e "[all:vars]\nansible_user=${USERNAME}" >> ${INVENTORYFILE}

	ansible-playbook -i ${INVENTORYFILE} cluster.yml -b --vault-password-file ${vaultpassfile} -e "@${credfile}" -e "@${cvarfile}" | tee ${logfile}
}
#########################
# Main script starts here

unset USERNAME PASSWORD INVENTORYFILE PROMPT
PROMPT=0

TEMP=`getopt -o u:p:i:n?h --long username:,password:,inventory:,prompt -- "$@"`
eval set -- "$TEMP"
# extract options and their arguments into variables.
while true ; do
    case "$1" in

    -u|--username) 	USERNAME=$2; shift 2 ;;
    -p|--password) 	PASSWORD=$2; shift 2 ;;
    -i|--inventory) INVENTORYFILE=$2; shift 2 ;;
    --prompt) PROMPT=1; shift ;;
    -h|?|--help) usage ;;
    --) shift ; break ;;
    *) usage

    esac
done

## Error handling
[ -z "${USERNAME}" ] && usage
[ -z "${PASSWORD}" ] && usage

# default inventory
[ -z "${INVENTORYFILE}" ] && INVENTORYFILE="inventory/ss8-k8s-cluster/inventory.ini"
[ ! -f ${INVENTORYFILE} ] && _error "Inventory file does not exist"
_info "Inventory file is being used: [${INVENTORYFILE}]"

####  Install ansible only if not installed
ansible --version
[ $? -ne 0 ] &&
       	install_pip_packages
####

enable_ssh
generate_vault

_info "pre-configuration is finished"

if [ $PROMPT -eq 0 ];then
	_info "--promt is not provided\nCreating cluster for inventory [${INVENTORYFILE}] ..."
	create_cluster
else
   _info "--prompt is provided."
    while true; do
      read -p "Do you wish to proceed to create the cluster?" yn
      case ${yn} in
        [Yy]* ) create_cluster; break;;
        [Nn]* ) _error "You can run below command to create cluster
  'ansible-playbook -i ${INVENTORYFILE} cluster.yml -b -e@${cvarfile} -K'";;
        * ) echo "Please answer yes or no.";;
      esac
    done
fi

