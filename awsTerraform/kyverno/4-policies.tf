# All policies depend on the Helm release so CRDs are guaranteed to exist.

resource "kubectl_manifest" "restrict_registries" {
  depends_on = [helm_release.kyverno]

  yaml_body = <<-YAML
    apiVersion: kyverno.io/v1
    kind: ClusterPolicy
    metadata:
      name: restrict-image-registries
      annotations:
        policies.kyverno.io/description: >-
          Only images from the project ECR registry are permitted.
          This prevents supply-chain attacks via public images.
    spec:
      validationFailureAction: Enforce
      background: true
      rules:
        - name: allow-ecr-only
          match:
            any:
            - resources:
                kinds: ["Pod"]
          exclude:
            any:
            - resources:
                namespaces: ${jsonencode(local.system_namespaces)}
          validate:
            message: "Images must be pulled from ${local.ecr_registry}. Found: {{request.object.spec.containers[].image}}"
            foreach:
            - list: "request.object.spec.containers"
              deny:
                conditions:
                  any:
                  - key: "{{element.image}}"
                    operator: NotEquals
                    value: "${local.ecr_registry}/*"
  YAML
}

resource "kubectl_manifest" "verify_image_signatures" {
  depends_on = [helm_release.kyverno]

  yaml_body = <<-YAML
    apiVersion: kyverno.io/v1
    kind: ClusterPolicy
    metadata:
      name: verify-image-signatures
      annotations:
        policies.kyverno.io/description: >-
          All images from the devsecops-lab ECR repository must have a valid
          keyless cosign signature issued by GitHub Actions via Sigstore.
    spec:
      validationFailureAction: Enforce
      background: false
      rules:
        - name: check-signature
          match:
            any:
            - resources:
                kinds: ["Pod"]
          exclude:
            any:
            - resources:
                namespaces: ${jsonencode(local.system_namespaces)}
          verifyImages:
          - imageReferences:
            - "${local.ecr_image}:*"
            attestors:
            - count: 1
              entries:
              - keyless:
                  subject: "${local.github_workflow_subject}"
                  issuer: "${local.github_oidc_issuer}"
                  rekor:
                    url: https://rekor.sigstore.dev
  YAML
}

resource "kubectl_manifest" "verify_sbom_attestation" {
  depends_on = [helm_release.kyverno]

  yaml_body = <<-YAML
    apiVersion: kyverno.io/v1
    kind: ClusterPolicy
    metadata:
      name: verify-sbom-attestation
      annotations:
        policies.kyverno.io/description: >-
          All images from the devsecops-lab ECR repository must have a valid
          SPDX SBOM attestation signed by GitHub Actions via Sigstore.
    spec:
      validationFailureAction: Enforce
      background: false
      rules:
        - name: check-sbom-attestation
          match:
            any:
            - resources:
                kinds: ["Pod"]
          exclude:
            any:
            - resources:
                namespaces: ${jsonencode(local.system_namespaces)}
          verifyImages:
          - imageReferences:
            - "${local.ecr_image}:*"
            attestations:
            - predicateType: https://spdx.dev/Document
              attestors:
              - count: 1
                entries:
                - keyless:
                    subject: "${local.github_workflow_subject}"
                    issuer: "${local.github_oidc_issuer}"
  YAML
}

resource "kubectl_manifest" "pod_security_baseline" {
  depends_on = [helm_release.kyverno]

  yaml_body = <<-YAML
    apiVersion: kyverno.io/v1
    kind: ClusterPolicy
    metadata:
      name: pod-security-baseline
      annotations:
        policies.kyverno.io/description: >-
          Enforces a security baseline for all pods: no privileged containers,
          no host namespaces, no hostPath volumes, non-root user, all capabilities
          dropped, and resource limits required.
    spec:
      validationFailureAction: Enforce
      background: true
      rules:
        - name: no-privileged
          match:
            any:
            - resources:
                kinds: ["Pod"]
          exclude:
            any:
            - resources:
                namespaces: ${jsonencode(local.system_namespaces)}
          validate:
            message: "Privileged containers are not allowed."
            pattern:
              spec:
                containers:
                - =(securityContext):
                    =(privileged): "false"

        - name: no-host-namespaces
          match:
            any:
            - resources:
                kinds: ["Pod"]
          exclude:
            any:
            - resources:
                namespaces: ${jsonencode(local.system_namespaces)}
          validate:
            message: "Host network, PID, and IPC namespaces are not allowed."
            pattern:
              spec:
                =(hostNetwork): "false"
                =(hostPID): "false"
                =(hostIPC): "false"

        - name: no-hostpath
          match:
            any:
            - resources:
                kinds: ["Pod"]
          exclude:
            any:
            - resources:
                namespaces: ${jsonencode(local.system_namespaces)}
          validate:
            message: "hostPath volumes are not allowed."
            deny:
              conditions:
                any:
                - key: "{{ request.object.spec.volumes[].hostPath | length(@) }}"
                  operator: GreaterThan
                  value: 0

        - name: require-non-root
          match:
            any:
            - resources:
                kinds: ["Pod"]
          exclude:
            any:
            - resources:
                namespaces: ${jsonencode(local.system_namespaces)}
          validate:
            message: "Containers must run as a non-root user."
            pattern:
              spec:
                containers:
                - securityContext:
                    runAsNonRoot: true

        - name: drop-all-capabilities
          match:
            any:
            - resources:
                kinds: ["Pod"]
          exclude:
            any:
            - resources:
                namespaces: ${jsonencode(local.system_namespaces)}
          validate:
            message: "All Linux capabilities must be dropped."
            pattern:
              spec:
                containers:
                - securityContext:
                    capabilities:
                      drop: ["ALL"]

        - name: require-resource-limits
          match:
            any:
            - resources:
                kinds: ["Pod"]
          exclude:
            any:
            - resources:
                namespaces: ${jsonencode(local.system_namespaces)}
          validate:
            message: "CPU and memory limits are required on all containers."
            pattern:
              spec:
                containers:
                - resources:
                    limits:
                      memory: "?*"
                      cpu: "?*"
  YAML
}
