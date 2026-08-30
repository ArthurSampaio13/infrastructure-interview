unit "kind_cluster" {
  source = "${get_repo_root()}/infra/units/kind-cluster"
  path   = "kind-cluster"
}

unit "platform_addons" {
  source = "${get_repo_root()}/infra/units/platform-addons"
  path   = "platform-addons"
}
