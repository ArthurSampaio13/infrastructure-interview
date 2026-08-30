# Single local environment; state lives next to it, gitignored.
remote_state {
  backend = "local"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    path = "${get_repo_root()}/infra/environments/local/.state/${basename(get_terragrunt_dir())}/terraform.tfstate"
  }
}
