output "kube_controller_nodes-profile" {
  value = aws_iam_instance_profile.kube_controller_nodes.name
}

output "kube-worker-profile" {
  value = aws_iam_instance_profile.kube-worker.name
}
