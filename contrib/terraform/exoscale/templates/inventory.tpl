[all]
${connection_strings_master}
${connection_strings_worker}

[kube_controller_nodes]
${list_master}

[kube_controller_nodes:vars]
supplementary_addresses_in_ssl_keys = [ "${api_lb_ip_address}" ]

[etcd]
${list_master}

[kube_worker_nodes]
${list_worker}

[k8s_cluster:children]
kube_controller_nodes
kube_worker_nodes
