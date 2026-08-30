include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_repo_root()}/infra/modules/platform-addons"
}

dependency "kind" {
  config_path = "../kind-cluster"
  mock_outputs = {
    kubeconfig_path = "/tmp/mock-kubeconfig"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

locals {
  common = yamldecode(file("${get_repo_root()}/infra/environments/common/addons.yaml"))
  env    = yamldecode(file(find_in_parent_folders("addons.yaml")))
}

inputs = merge(local.common, local.env, {
  kubeconfig_path = dependency.kind.outputs.kubeconfig_path
})
