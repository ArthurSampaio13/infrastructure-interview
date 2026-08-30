locals {
  zone_patch = { for z in ["zone-a", "zone-b", "zone-c"] : z => <<-EOT
    kind: JoinConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "topology.kubernetes.io/zone=${z}"
  EOT
  }
}

resource "kind_cluster" "this" {
  name           = var.cluster_name
  wait_for_ready = true

  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"

    node {
      role = "control-plane"
    }

    node {
      role                   = "worker"
      kubeadm_config_patches = [local.zone_patch["zone-a"]]

      extra_port_mappings {
        container_port = 30080
        host_port      = 80
      }
      extra_port_mappings {
        container_port = 30443
        host_port      = 443
      }
    }

    node {
      role                   = "worker"
      kubeadm_config_patches = [local.zone_patch["zone-b"]]
    }

    node {
      role                   = "worker"
      kubeadm_config_patches = [local.zone_patch["zone-c"]]
    }
  }
}

resource "local_sensitive_file" "kubeconfig" {
  content         = kind_cluster.this.kubeconfig
  filename        = pathexpand(var.kubeconfig_path)
  file_permission = "0600"
}
