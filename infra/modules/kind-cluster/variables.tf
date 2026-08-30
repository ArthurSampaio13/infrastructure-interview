variable "cluster_name" {
  description = "kind cluster name"
  type        = string
}

variable "kubeconfig_path" {
  description = "Where to write the kubeconfig"
  type        = string
}
