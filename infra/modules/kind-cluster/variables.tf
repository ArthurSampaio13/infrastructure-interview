variable "cluster_name" {
  description = "kind cluster name"
  type        = string
}

variable "kubeconfig_path" {
  description = "Where to write the kubeconfig"
  type        = string
}

variable "node_image" {
  description = "kindest/node image, tag and digest, matching the kubectl version in mise.toml"
  type        = string
}
