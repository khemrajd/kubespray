[all]
${connection_strings_master}
${connection_strings_node}
${connection_strings_etcd}
${public_ip_address_bastion}

[bastion]
${public_ip_address_bastion}

[kube_controller_nodes]
${list_master}


[kube_worker_nodes]
${list_node}


[etcd]
${list_etcd}


[k8s_cluster:children]
kube_worker_nodes
kube_controller_nodes


[k8s_cluster:vars]
${elb_api_fqdn}
