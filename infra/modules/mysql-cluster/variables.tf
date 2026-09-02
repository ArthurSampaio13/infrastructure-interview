variable "kubeconfig_path" {
  description = "Path to the cluster kubeconfig"
  type        = string
}

variable "instances" {
  description = "MySQL server instances"
  type        = number
}

variable "router_instances" {
  description = "MySQL router instances"
  type        = number
}

variable "db_name" {
  description = "Application database name"
  type        = string
}

variable "db_user" {
  description = "Application database user"
  type        = string
}

variable "db_migration_user" {
  description = "Database user that runs schema migrations (DDL); the application user only gets DML"
  type        = string
}
