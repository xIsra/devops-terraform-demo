# -----------------------------------------------------------------------------
# Nginx Ingress Controller
# Deployed via Helm - provides ingress routing with SSL/TLS support
# For local domains (e.g., devops-demo.local), use self-signed certificates
# Make sure to add the domain to /etc/hosts: 127.0.0.1 devops-demo.local
# -----------------------------------------------------------------------------

resource "helm_release" "ingress_nginx" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  namespace        = "ingress-nginx"
  create_namespace = true
  version          = "4.10.0"
  timeout          = 600

  # Kind-specific configuration
  values = [
    <<-EOT
    controller:
      hostPort:
        enabled: true
        ports:
          http: 80
          https: 443
      nodeSelector:
        ingress-ready: "true"
      tolerations:
        - key: node-role.kubernetes.io/control-plane
          operator: Exists
          effect: NoSchedule
      service:
        type: ClusterIP
      admissionWebhooks:
        enabled: false  # Disable for Kind to avoid issues
    EOT
  ]

  depends_on = [kind_cluster.this]
}

# Wait for Nginx ingress controller to be ready
resource "null_resource" "wait_for_ingress" {
  provisioner "local-exec" {
    command = <<-EOT
      echo "Waiting for Nginx ingress controller to be ready..."
      # Wait for namespace to be created
      for i in {1..30}; do
        if kubectl get namespace ingress-nginx &>/dev/null; then
          break
        fi
        sleep 2
      done
      # Wait for pods to be ready
      kubectl wait --namespace ingress-nginx \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/component=controller \
        --timeout=300s || echo "Warning: Some pods may not be ready yet"
    EOT
  }

  depends_on = [helm_release.ingress_nginx]
}
