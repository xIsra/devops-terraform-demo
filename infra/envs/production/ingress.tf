# -----------------------------------------------------------------------------
# Nginx Ingress Controller
# Deployed via Helm for production-grade ingress management
# Services define their own ingress rules via the service module
# -----------------------------------------------------------------------------

resource "helm_release" "ingress_nginx" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  namespace        = "ingress-nginx"
  create_namespace = true
  version          = "4.10.0"

  # Kind-specific configuration
  # See: https://kind.sigs.k8s.io/docs/user/ingress/#ingress-nginx
  values = [
    <<-EOT
    controller:
      hostPort:
        enabled: true
      service:
        type: NodePort
      nodeSelector:
        ingress-ready: "true"
      tolerations:
        - key: node-role.kubernetes.io/control-plane
          operator: Exists
          effect: NoSchedule
      watchIngressWithoutClass: true
      ingressClassResource:
        default: true
    EOT
  ]

  depends_on = [kind_cluster.this]
}

# Wait for ingress controller to be ready before creating ingress resources
resource "null_resource" "wait_for_ingress" {
  provisioner "local-exec" {
    command = <<-EOT
      echo "Waiting for ingress-nginx to be ready..."
      kubectl wait --namespace ingress-nginx \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/component=controller \
        --timeout=120s
    EOT
  }

  depends_on = [helm_release.ingress_nginx]
}
