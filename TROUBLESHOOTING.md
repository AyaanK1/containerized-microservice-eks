# Troubleshooting Log

Real issues found while wiring this project to the shared
[`terraform-module-library`](https://github.com/AyaanK1/terraform-module-library)
and fixing them.

## 1. Output name mismatch: `cluster_certificate_authority` vs `cluster_certificate_authority_data`

**Issue:** the Kubernetes and Helm providers need the EKS cluster's CA
certificate to authenticate. I initially referenced
`module.eks.cluster_certificate_authority_data`, following the naming
convention used by some public Terraform registry modules. The library's
actual `eks` module exports it as `cluster_certificate_authority` (no
`_data` suffix) — a plan would have failed immediately with an "unsupported
attribute" error.

**Fix:** Read the module's actual `outputs` block in
`modules/eks/main.tf` before wiring the provider, and corrected the
reference to `module.eks.cluster_certificate_authority`.

## 2. Helm chart path must resolve relative to the module, not the CLI's working directory

**Issue:** `helm_release.app` originally referenced the chart via a bare
relative path (`../helm/app`), which Terraform resolves relative to the
directory `terraform` is invoked from — not this module's own file
location. That breaks if `terraform apply` is ever run from a different
working directory (e.g., from a CI runner's repo root).

**Fix:** Used `"${path.module}/../helm/app"` instead, so the chart path
always resolves relative to this Terraform module regardless of where the
command is invoked from.

## 3. IAM push vs. pull separation

**Design decision, not a bug:** the library's `eks` module only attaches
`AmazonEC2ContainerRegistryReadOnly` to the node role — nodes should only
ever need to *pull* images, never push. Push access for the CI/CD pipeline
is granted separately to the GitHub Actions OIDC role
(`AWS_ROLE_ARN` secret), keeping the node role at least-privilege rather
than over-provisioning it with permissions it doesn't use at runtime.

## 4. Ordering dependency between namespace creation and Helm release

**Issue:** the Helm release targets a Kubernetes namespace
(`microservice-app`) that Terraform also manages
(`kubernetes_namespace.app`). Without an explicit dependency, Terraform's
graph doesn't guarantee the namespace exists before Helm tries to deploy
into it.

**Fix:** Added `depends_on = [kubernetes_namespace.app]` to `helm_release.app`.

## Note on validation

This sandbox couldn't install the Terraform CLI directly (network policy
blocks `releases.hashicorp.com`), so `terraform validate`/`plan` couldn't be
run here. Everything above was caught by manually reading the library's
actual module source (cloned from GitHub) and cross-checking every
variable/output name used against it. Run `terraform init && terraform
validate` locally before applying to catch anything this review missed.
