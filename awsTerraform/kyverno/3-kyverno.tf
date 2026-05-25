resource "helm_release" "kyverno" {
  name             = "kyverno"
  repository       = "https://kyverno.github.io/kyverno/"
  chart            = "kyverno"
  namespace        = "kyverno"
  create_namespace = true

  # Wait until all Kyverno pods and webhooks are ready before policies are applied
  wait          = true
  wait_for_jobs = true
  timeout       = 300

  set {
    name  = "admissionController.replicas"
    value = "1"
  }

  set {
    name  = "backgroundController.replicas"
    value = "1"
  }

  set {
    name  = "cleanupController.replicas"
    value = "1"
  }

  set {
    name  = "reportsController.replicas"
    value = "1"
  }

  # Ignore — prevents cluster lockout if Kyverno restarts on a single-replica dev setup.
  # Change to Fail for production.
  set {
    name  = "webhooksCleanup.enable"
    value = "true"
  }

  set {
    name  = "config.webhooks[0].failurePolicy"
    value = "Ignore"
  }
}
