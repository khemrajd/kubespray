
[all]
${connection_strings_master}
${connection_strings_worker}

[kube_controller_nodes]
${list_master}

[etcd]
${list_master}

[kube_worker_nodes]
${list_worker}

[k8s_cluster:children]
kube_controller_nodes
kube_worker_nodes
