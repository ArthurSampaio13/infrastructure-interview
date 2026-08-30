include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_repo_root()}/infra/modules/kind-cluster"
}

locals {
  common = yamldecode(file("${get_repo_root()}/infra/environments/common/cluster.yaml"))
  env    = yamldecode(file(find_in_parent_folders("cluster.yaml")))
}

inputs = merge(local.common, local.env)
