resource "kubectl_manifest" "issuer_selfsigned" {
  yaml_body  = <<-EOT
    apiVersion: cert-manager.io/v1
    kind: ClusterIssuer
    metadata:
      name: selfsigned
    spec:
      selfSigned: {}
  EOT
  depends_on = [helm_release.cert_manager]
}

resource "kubectl_manifest" "local_ca_cert" {
  yaml_body  = <<-EOT
    apiVersion: cert-manager.io/v1
    kind: Certificate
    metadata:
      name: local-ca
      namespace: cert-manager
    spec:
      isCA: true
      commonName: local-ca
      secretName: local-ca
      privateKey:
        algorithm: ECDSA
        size: 256
      issuerRef:
        name: selfsigned
        kind: ClusterIssuer
  EOT
  depends_on = [kubectl_manifest.issuer_selfsigned]
}

resource "kubectl_manifest" "issuer_local_ca" {
  yaml_body  = <<-EOT
    apiVersion: cert-manager.io/v1
    kind: ClusterIssuer
    metadata:
      name: local-ca
    spec:
      ca:
        secretName: local-ca
  EOT
  depends_on = [kubectl_manifest.local_ca_cert]
}

resource "kubectl_manifest" "gateway" {
  yaml_body  = <<-EOT
    apiVersion: gateway.networking.k8s.io/v1
    kind: Gateway
    metadata:
      name: gateway
      namespace: gateway
      annotations:
        cert-manager.io/cluster-issuer: local-ca
    spec:
      gatewayClassName: nginx
      listeners:
        - name: http
          port: 80
          protocol: HTTP
          allowedRoutes:
            namespaces:
              from: Same
        - name: https
          port: 443
          protocol: HTTPS
          hostname: "*.local.test"
          tls:
            mode: Terminate
            certificateRefs:
              - name: gateway-tls
          allowedRoutes:
            namespaces:
              from: All
  EOT
  depends_on = [helm_release.ngf, kubectl_manifest.issuer_local_ca, kubernetes_namespace.gateway]
}

resource "kubectl_manifest" "redirect_to_https" {
  yaml_body  = <<-EOT
    apiVersion: gateway.networking.k8s.io/v1
    kind: HTTPRoute
    metadata:
      name: redirect-to-https
      namespace: gateway
    spec:
      parentRefs:
        - name: gateway
          sectionName: http
      rules:
        - filters:
            - type: RequestRedirect
              requestRedirect:
                scheme: https
                statusCode: 301
  EOT
  depends_on = [kubectl_manifest.gateway]
}

resource "kubectl_manifest" "grafana_httproute" {
  yaml_body  = <<-EOT
    apiVersion: gateway.networking.k8s.io/v1
    kind: HTTPRoute
    metadata:
      name: grafana
      namespace: monitoring
    spec:
      parentRefs:
        - name: gateway
          namespace: gateway
          sectionName: https
      hostnames:
        - grafana.local.test
      rules:
        - backendRefs:
            - name: kube-prometheus-stack-grafana
              port: 80
  EOT
  depends_on = [kubectl_manifest.gateway, helm_release.kube_prometheus_stack]
}

resource "kubectl_manifest" "ngf_podmonitor" {
  yaml_body  = <<-EOT
    apiVersion: monitoring.coreos.com/v1
    kind: PodMonitor
    metadata:
      name: ngf
      namespace: nginx-gateway
    spec:
      selector:
        matchLabels:
          app.kubernetes.io/name: nginx-gateway-fabric
      podMetricsEndpoints:
        - port: metrics
  EOT
  depends_on = [helm_release.ngf, helm_release.kube_prometheus_stack]
}

resource "kubectl_manifest" "gateway_nginx_pdb" {
  yaml_body  = <<-EOT
    apiVersion: policy/v1
    kind: PodDisruptionBudget
    metadata:
      name: gateway-nginx
      namespace: gateway
    spec:
      maxUnavailable: 1
      selector:
        matchLabels:
          app.kubernetes.io/name: gateway-nginx
  EOT
  depends_on = [kubectl_manifest.gateway]
}
