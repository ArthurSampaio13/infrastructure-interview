resource "kubernetes_namespace" "mysql" {
  metadata {
    name = "mysql"
    # the operator runs a root init container to fix the datadir, so restricted would reject it
    labels = {
      "pod-security.kubernetes.io/enforce" = "baseline"
      "pod-security.kubernetes.io/warn"    = "baseline"
      "pod-security.kubernetes.io/audit"   = "baseline"
    }
  }
}

resource "kubernetes_namespace" "app" {
  metadata {
    name = "posts-api"
    labels = {
      "pod-security.kubernetes.io/enforce" = "restricted"
      "pod-security.kubernetes.io/warn"    = "restricted"
      "pod-security.kubernetes.io/audit"   = "restricted"
    }
  }
}

resource "random_password" "root" {
  length  = 24
  special = false
}

resource "random_password" "app" {
  length  = 24
  special = false
}

resource "kubernetes_secret" "root" {
  metadata {
    name      = "mysql-root"
    namespace = kubernetes_namespace.mysql.metadata[0].name
  }
  data = {
    rootUser     = "root"
    rootHost     = "%"
    rootPassword = random_password.root.result
  }
}

resource "kubernetes_secret" "app_user" {
  metadata {
    name      = "posts-app-user"
    namespace = kubernetes_namespace.mysql.metadata[0].name
  }
  data = {
    password = random_password.app.result
  }
}

resource "kubectl_manifest" "innodb_cluster" {
  yaml_body  = <<-EOT
    apiVersion: mysql.oracle.com/v2
    kind: InnoDBCluster
    metadata:
      name: mysql
      namespace: mysql
    spec:
      secretName: mysql-root
      tlsUseSelfSigned: true
      instances: ${var.instances}
      router:
        instances: ${var.router_instances}
        podSpec:
          containers:
            - name: router
              resources:
                requests:
                  cpu: 100m
                  memory: 128Mi
                limits:
                  memory: 256Mi
      datadirVolumeClaimTemplate:
        accessModes: ["ReadWriteOnce"]
        resources:
          requests:
            storage: 2Gi
      mycnf: |
        [mysqld]
        loose_group_replication_message_cache_size=128M
      podSpec:
        containers:
          - name: mysql
            resources:
              requests:
                cpu: 250m
                memory: 512Mi
              limits:
                memory: 1536Mi
        topologySpreadConstraints:
          - maxSkew: 1
            topologyKey: topology.kubernetes.io/zone
            whenUnsatisfiable: DoNotSchedule
            labelSelector:
              matchLabels:
                mysql.oracle.com/cluster: mysql
      metrics:
        enable: true
        image: prom/mysqld-exporter:v0.15.1
  EOT
  depends_on = [kubernetes_secret.root]
}

resource "kubectl_manifest" "mysql_podmonitor" {
  yaml_body  = <<-EOT
    apiVersion: monitoring.coreos.com/v1
    kind: PodMonitor
    metadata:
      name: mysql
      namespace: mysql
    spec:
      selector:
        matchLabels:
          mysql.oracle.com/cluster: mysql
      podMetricsEndpoints:
        - port: metrics
  EOT
  depends_on = [kubectl_manifest.innodb_cluster]
}

resource "null_resource" "wait_online" {
  provisioner "local-exec" {
    command = "kubectl --kubeconfig ${var.kubeconfig_path} wait innodbcluster/mysql -n mysql --for=jsonpath='{.status.cluster.status}'=ONLINE --timeout=900s"
  }
  depends_on = [kubectl_manifest.innodb_cluster]
}

resource "kubernetes_job" "app_user" {
  metadata {
    name      = "create-app-user"
    namespace = kubernetes_namespace.mysql.metadata[0].name
  }
  spec {
    backoff_limit = 4
    template {
      metadata {}
      spec {
        restart_policy = "Never"
        container {
          name  = "mysql-client"
          image = "mysql:8.4"
          env {
            name = "MYSQL_PWD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.root.metadata[0].name
                key  = "rootPassword"
              }
            }
          }
          env {
            name = "APP_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.app_user.metadata[0].name
                key  = "password"
              }
            }
          }
          command = ["bash", "-c", <<-EOT
            mysql -h mysql.mysql.svc.cluster.local -P 6446 -uroot -e "
              CREATE DATABASE IF NOT EXISTS ${var.db_name};
              CREATE USER IF NOT EXISTS '${var.db_user}'@'%' IDENTIFIED BY '$APP_PASSWORD';
              GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, ALTER, INDEX, DROP, REFERENCES ON ${var.db_name}.* TO '${var.db_user}'@'%';"
          EOT
          ]
        }
      }
    }
  }
  wait_for_completion = true
  timeouts {
    create = "10m"
  }
  depends_on = [null_resource.wait_online]
}

resource "kubernetes_secret" "app_db" {
  metadata {
    name      = "posts-api-db"
    namespace = kubernetes_namespace.app.metadata[0].name
  }
  data = {
    DB_HOST     = "mysql.mysql.svc.cluster.local"
    DB_PORT     = "6446"
    DB_USER     = var.db_user
    DB_PASSWORD = random_password.app.result
    DB_NAME     = var.db_name
  }
  depends_on = [kubernetes_job.app_user]
}
