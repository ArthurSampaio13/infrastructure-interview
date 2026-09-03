<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11.0 |
| <a name="requirement_kind"></a> [kind](#requirement\_kind) | ~> 0.9 |
| <a name="requirement_local"></a> [local](#requirement\_local) | ~> 2.5 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_kind"></a> [kind](#provider\_kind) | 0.11.0 |
| <a name="provider_local"></a> [local](#provider\_local) | 2.9.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [kind_cluster.this](https://registry.terraform.io/providers/tehcyx/kind/latest/docs/resources/cluster) | resource |
| [local_sensitive_file.kubeconfig](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/sensitive_file) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | kind cluster name | `string` | n/a | yes |
| <a name="input_kubeconfig_path"></a> [kubeconfig\_path](#input\_kubeconfig\_path) | Where to write the kubeconfig | `string` | n/a | yes |
| <a name="input_node_image"></a> [node\_image](#input\_node\_image) | kindest/node image, tag and digest, matching the kubectl version in mise.toml | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | kind cluster name |
| <a name="output_kubeconfig_path"></a> [kubeconfig\_path](#output\_kubeconfig\_path) | Path to the generated kubeconfig |
<!-- END_TF_DOCS -->
