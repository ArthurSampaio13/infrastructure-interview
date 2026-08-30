include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_repo_root()}/infra/modules/mysql-cluster"
}

dependency "kind" {
  config_path = "../kind-cluster"
  mock_outputs = {
    kubeconfig_path = "/tmp/mock-kubeconfig"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

dependency "addons" {
  config_path  = "../platform-addons"
  skip_outputs = true
}

locals {
  common = yamldecode(file("${get_repo_root()}/infra/environments/common/database.yaml"))
  env    = yamldecode(file(find_in_parent_folders("database.yaml")))
}

inputs = merge(local.common, local.env, {
  kubeconfig_path = dependency.kind.outputs.kubeconfig_path
})
