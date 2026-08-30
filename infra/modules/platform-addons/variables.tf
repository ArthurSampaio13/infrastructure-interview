variable "kubeconfig_path" {
  description = "Path to the cluster kubeconfig"
  type        = string
}

variable "chart_versions" {
  description = "Pinned helm chart versions per addon"
  type        = map(string)
}
