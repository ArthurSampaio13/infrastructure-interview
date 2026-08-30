resource "null_resource" "gateway_api_crds" {
  triggers = {
    version = var.chart_versions.nginx_gateway_fabric
  }

  provisioner "local-exec" {
    command = "kubectl --kubeconfig ${var.kubeconfig_path} apply -k 'https://github.com/nginx/nginx-gateway-fabric/config/crd/gateway-api/standard?ref=v${var.chart_versions.nginx_gateway_fabric}'"
  }
}

resource "kubernetes_namespace" "gateway" {
  metadata {
    name = "gateway"
  }
}

resource "helm_release" "ngf" {
  name             = "ngf"
  repository       = "oci://ghcr.io/nginx/charts"
  chart            = "nginx-gateway-fabric"
  version          = var.chart_versions.nginx_gateway_fabric
  namespace        = "nginx-gateway"
  create_namespace = true
  values           = [file("${path.module}/templates/ngf.yaml")]
  depends_on       = [null_resource.gateway_api_crds]
}

resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = var.chart_versions.cert_manager
  namespace        = "cert-manager"
  create_namespace = true
  values           = [file("${path.module}/templates/cert-manager.yaml")]
  depends_on       = [null_resource.gateway_api_crds]
}

resource "random_password" "grafana" {
  length  = 20
  special = false
}

resource "helm_release" "kube_prometheus_stack" {
  name             = "kube-prometheus-stack"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  version          = var.chart_versions.kube_prometheus_stack
  namespace        = "monitoring"
  create_namespace = true
  timeout          = 900
  values = [templatefile("${path.module}/templates/kps.yaml.tftpl", {
    grafana_password = random_password.grafana.result
  })]
}

resource "helm_release" "loki" {
  name       = "loki"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "loki"
  version    = var.chart_versions.loki
  namespace  = "monitoring"
  values     = [file("${path.module}/templates/loki.yaml")]
  depends_on = [helm_release.kube_prometheus_stack]
}

resource "helm_release" "alloy" {
  name       = "alloy"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "alloy"
  version    = var.chart_versions.alloy
  namespace  = "monitoring"
  values     = [file("${path.module}/templates/alloy.yaml")]
  depends_on = [helm_release.loki]
}

resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  version    = var.chart_versions.metrics_server
  namespace  = "kube-system"
  values     = [file("${path.module}/templates/metrics-server.yaml")]
}

resource "helm_release" "mysql_operator" {
  name             = "mysql-operator"
  repository       = "https://mysql.github.io/mysql-operator/"
  chart            = "mysql-operator"
  version          = var.chart_versions.mysql_operator
  namespace        = "mysql-operator"
  create_namespace = true
}
