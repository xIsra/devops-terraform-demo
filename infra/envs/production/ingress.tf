# -----------------------------------------------------------------------------
# Caddy Ingress Controller
# Deployed via Helm - provides automatic HTTPS with Let's Encrypt
# For localhost, Caddy uses self-signed certificates automatically
# -----------------------------------------------------------------------------

resource "helm_release" "caddy" {
  name             = "caddy"
  repository       = "https://caddyserver.github.io/ingress"
  chart            = "caddy-ingress-controller"
  namespace        = "caddy-system"
  create_namespace = true
  version          = "1.3.0"
  timeout          = 600
  atomic           = false
  wait             = false

  # Kind-specific configuration
  values = [
    <<-EOT
    ingressController:
      config:
        # Enable automatic HTTPS for localhost (self-signed)
        # For production domains, Caddy automatically uses Let's Encrypt
        email: admin@localhost
      nodeSelector:
        ingress-ready: "true"
      tolerations:
        - key: node-role.kubernetes.io/control-plane
          operator: Exists
          effect: NoSchedule
    service:
      type: ClusterIP
    ingressClass:
      name: caddy
      default: true
    EOT
  ]

  depends_on = [kind_cluster.this]
}

# Patch deployment to use hostPort for Kind compatibility
resource "null_resource" "patch_caddy_hostport" {
  provisioner "local-exec" {
    command = <<-EOT
      echo "Patching Caddy deployment to use hostPort for Kind..."
      # Wait for deployment to exist
      DEPLOYMENT_NAME=$(kubectl get deployment -n caddy-system -l app.kubernetes.io/name=caddy-ingress-controller -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
      if [ -z "$DEPLOYMENT_NAME" ]; then
        echo "Waiting for deployment..."
        for i in {1..30}; do
          DEPLOYMENT_NAME=$(kubectl get deployment -n caddy-system -l app.kubernetes.io/name=caddy-ingress-controller -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
          if [ -n "$DEPLOYMENT_NAME" ]; then
            break
          fi
          sleep 2
        done
      fi
      if [ -n "$DEPLOYMENT_NAME" ]; then
        # Patch deployment to add hostPort using strategic merge
        kubectl patch deployment "$DEPLOYMENT_NAME" -n caddy-system --type='strategic' -p='{
          "spec": {
            "template": {
              "spec": {
                "containers": [{
                  "name": "caddy-ingress-controller",
                  "ports": [
                    {"containerPort": 80, "hostPort": 80, "protocol": "TCP"},
                    {"containerPort": 443, "hostPort": 443, "protocol": "TCP"}
                  ]
                }]
              }
            }
          }
        }' || echo "Warning: Could not patch deployment"
        # Ensure pods are scheduled on control-plane node
        kubectl patch deployment "$DEPLOYMENT_NAME" -n caddy-system --type='strategic' -p='{
          "spec": {
            "template": {
              "spec": {
                "nodeSelector": {"ingress-ready": "true"},
                "tolerations": [{"key": "node-role.kubernetes.io/control-plane", "operator": "Exists", "effect": "NoSchedule"}]
              }
            }
          }
        }' || true
      fi
    EOT
  }

  depends_on = [helm_release.caddy]
}

# Wait for Caddy ingress controller to be ready
resource "null_resource" "wait_for_ingress" {
  provisioner "local-exec" {
    command = <<-EOT
      echo "Waiting for Caddy ingress controller to be ready..."
      # Wait for namespace to be created
      for i in {1..30}; do
        if kubectl get namespace caddy-system &>/dev/null; then
          break
        fi
        sleep 2
      done
      # Wait for pods to be ready
      kubectl wait --namespace caddy-system \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/name=caddy-ingress-controller \
        --timeout=300s || echo "Warning: Some pods may not be ready yet"
    EOT
  }

  depends_on = [null_resource.patch_caddy_hostport]
}
