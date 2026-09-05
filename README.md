# Containerized Microservice on EKS

A minimal Flask microservice deployed to Amazon EKS via Terraform and Helm,
with a GitHub Actions pipeline that builds the image, pushes it to ECR, and
rolls it out to the cluster.

## Architecture

- **VPC**: 2 AZs, public + private subnets, NAT gateway per AZ — from the
  [`terraform-module-library`](https://github.com/AyaanK1/terraform-module-library) `vpc` module
- **EKS**: managed control plane + managed node group in private subnets —
  from the library's `eks` module
- **ECR**: image repository with a lifecycle policy (expires untagged images
  after 7 days, keeps the most recent tagged releases) — from the library's
  `ecr` module
- **Security Group**: app-tier security group scoped to VPC-internal traffic
  only — from the library's `security-group` module
- **Helm**: templated Deployment, Service, and HorizontalPodAutoscaler
- **CI/CD**: GitHub Actions builds the Docker image, pushes to ECR, and runs
  `helm upgrade --install` against the cluster on every push to `main`

This project is the *consumer* of the shared module library rather than
redefining VPC/EKS/ECR/security-group logic inline — see
`terraform/main.tf`, which sources all four modules directly from
`github.com/AyaanK1/terraform-module-library`.

## Repo layout

```
terraform/          Root module + vpc/eks/ecr submodules
helm/app/           Helm chart for the Flask service
app/                Application source + Dockerfile
.github/workflows/  CI/CD pipeline
TROUBLESHOOTING.md  Issues hit while building this, and how they were fixed
```

## Deploying

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

Requires AWS credentials with permissions to create VPC, EKS, IAM, and ECR
resources, and `kubectl`/`helm` installed locally for the Kubernetes/Helm
providers to authenticate against the new cluster.

## Local app testing

```bash
cd app/src
pip install -r requirements.txt
python main.py
# curl localhost:8080/healthz
```

See `TROUBLESHOOTING.md` for issues found and their fixes.
