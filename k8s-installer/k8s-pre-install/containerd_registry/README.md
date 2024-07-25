### prerequisite ####

* openssl tool need for creating ssl self signed certifigate 
 
### Role Name ###
- containerd_registry
Role containerd_registry is to create private registry on remote server mentioned in inventory under group 'registry'.
This will copy registry image and other offline files to install & start conatinerd, create registry container instance.

### Requirements ###

* Registry IP in group['registry'] and create_registry flag
*
### Role Variables ###

#### Set the below variables in inventory file ####
[registry] --> anisble group name
node-reg ansible_host=1.2.3.4	--> Server on which container registry needs to create

#### Name of the registry conatiner instance ####
registry_container_name: "ss8-registry" (default)

#### host path acts as container volume for persistence of images data, eg: NFS share file system path ####
registry_volume=/SS8/registry (default)
* This is Host file system path where image data can stored when one pushes image to registry.
  This path acts as containerd volume to get benefit of storage persistent

#### Cutom port on which registry can be accessible on the ansible_host menioned above ####
registry_port=5000 (default)

### Dependencies ###
* Offline files: registry image, containerd and nerdctl binaries 

### Registry creation command along with k8s cluster creation (need to set this value true "create_registry=true"): ###
* :  k8s-pre-install/registry-setup.sh -i k8s-pre-install/registry.ini -u REMOTE_USER -p REMOTE_USER_PSWD [--args -vv]
 Optionally:
 ./kubespray-venv/bin/ansible-playbook -b -e@cvar.yaml -v k8s-pre-install/registry.yml \
 -e ansible_user=support -e ansible_sudo_pass=ss8inc -i k8s-pre-install/registry.ini


#### To verify whether registry is up running as expected ####
1.Log in into registry server and run the below command to test container registry is created successfully

$ nerdctl ps  | grep registry
If you see output as below where registry container STATUS is up then registry is successfully created
e02b06f9c2b0   docker.io/library/registry:2.8.1    "/entrypoint.sh /etc…"    4 minutes ago  Up  0.0.0.0:5000->5000/tcp    ss8-registry

run 'nerdctl ps --namespace k8s.io' if above 'nerdctl ps' command fails
