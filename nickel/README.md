# Nickel deployment targets

This folder contains [Nickel](https://nickel-lang.org/) configuration to generate deployment artifacts for the Elastic stack from a single source of truth. Targets: **local Docker**, **Minikube**, **AWS (EKS)**, and **Google Cloud (GKE)**.

- **`config.ncl`** – Shared config (passwords, versions, ports). Override from the CLI with `-- Key=value`.
- **`targets/local-docker.ncl`** – Exports config for `.env` (used by `docker-compose` + `elastic-container.sh`).
- **`targets/minikube.ncl`** – Kubernetes `List` manifest for Minikube.
- **`targets/aws.ncl`** – Kubernetes manifest for EKS.
- **`targets/gcp.ncl`** – Kubernetes manifest for GKE.

All commands below assume you are in the **repo root** (parent of `nickel/`), unless noted.

---

## Testing locally with Docker

You can run Nickel via Docker without installing it. Use a bind-mount so Nickel can read the `.ncl` files.

### Nickel CLI help

```bash
docker run --rm ghcr.io/tweag/nickel:1.10.0 export --help
```

### Export config as JSON (local-docker)

```bash
docker run --rm -v "$(pwd):/work" -w /work ghcr.io/tweag/nickel:1.10.0 export nickel/targets/local-docker.ncl --format json
```

### Export config as YAML (minikube / aws / gcp)

```bash
# Minikube
docker run --rm -v "$(pwd):/work" -w /work ghcr.io/tweag/nickel:1.10.0 export nickel/targets/minikube.ncl --format yaml

# AWS (EKS)
docker run --rm -v "$(pwd):/work" -w /work ghcr.io/tweag/nickel:1.10.0 export nickel/targets/aws.ncl --format yaml

# GCP (GKE)
docker run --rm -v "$(pwd):/work" -w /work ghcr.io/tweag/nickel:1.10.0 export nickel/targets/gcp.ncl --format yaml
```

### Override config from the CLI

Pass overrides after `--`. Use `\"` for values that contain spaces or special characters.

```bash
docker run --rm -v "$(pwd):/work" -w /work ghcr.io/tweag/nickel:1.10.0 export nickel/targets/local-docker.ncl --format json -- \
  ELASTIC_PASSWORD=\"mysecret\" \
  KIBANA_PASSWORD=\"mykibanasecret\" \
  STACK_VERSION=\"8.14.0\"
```

### Using the helper script (from repo root)

The script runs Nickel via Docker and writes into `generated/` (or a path you pass):

```bash
# Local Docker: print .env to stdout and write generated/.env
./scripts/nickel-export.sh local-docker

# Local Docker: only print (no file)
./scripts/nickel-export.sh local-docker -

# Minikube / AWS / GCP: write YAML to generated/<target>/stack.yaml
./scripts/nickel-export.sh minikube generated/minikube
./scripts/nickel-export.sh aws generated/aws
./scripts/nickel-export.sh gcp generated/gcp
```

---

## Deploying with each provider

### Local Docker

1. **Generate `.env`** (optional; you can keep using your existing `.env`):

   ```bash
   ./scripts/nickel-export.sh local-docker generated
   cp generated/.env .env
   ```

   Or overwrite repo `.env` (back up first):

   ```bash
   cp .env .env.bak
   ./scripts/nickel-export.sh local-docker .
   ```

2. **Edit `.env`** – Set real passwords (replace `changeme`) and any other options.

3. **Start the stack** (unchanged from main README):

   ```bash
   chmod +x elastic-container.sh
   ./elastic-container.sh start
   ```

4. Open https://localhost:5601 and log in with the credentials from `.env`.

---

### Minikube

1. **Generate manifests**:

   ```bash
   ./scripts/nickel-export.sh minikube generated/minikube
   ```

   Or with Nickel directly:

   ```bash
   docker run --rm -v "$(pwd):/work" -w /work ghcr.io/tweag/nickel:1.10.0 export nickel/targets/minikube.ncl --format yaml > generated/minikube/stack.yaml
   ```

2. **Start Minikube** (if not already running):

   ```bash
   minikube start
   ```

3. **Apply the stack**:

   ```bash
   kubectl apply -f generated/minikube/stack.yaml
   ```

4. **Wait for pods and access Kibana**:

   ```bash
   kubectl -n elastic get pods -w
   kubectl -n elastic get svc
   # Use minikube service or port-forward, e.g.:
   kubectl -n elastic port-forward svc/ecp-kibana 5601:5601
   ```

   Then open https://localhost:5601 (or the URL Minikube reports). The generated manifest uses a `Secret` for passwords; for production use a secrets manager or Sealed Secrets.

---

### AWS (EKS)

1. **Generate manifests**:

   ```bash
   ./scripts/nickel-export.sh aws generated/aws
   ```

   Or with Nickel directly:

   ```bash
   mkdir -p generated/aws
   docker run --rm -v "$(pwd):/work" -w /work ghcr.io/tweag/nickel:1.10.0 export nickel/targets/aws.ncl --format yaml > generated/aws/stack.yaml
   ```

2. **Configure kubectl for your EKS cluster**:

   ```bash
   aws eks update-kubeconfig --region <region> --name <cluster-name>
   ```

3. **Apply the stack**:

   ```bash
   kubectl apply -f generated/aws/stack.yaml
   ```

4. **Check resources and expose Kibana** (e.g. LoadBalancer / Ingress):

   ```bash
   kubectl -n elastic get pods,svc
   ```

   Adjust storage (e.g. EBS), ingress, and secrets (e.g. External Secrets, AWS Secrets Manager) as needed for your environment.

---

### Google Cloud (GKE)

1. **Generate manifests**:

   ```bash
   ./scripts/nickel-export.sh gcp generated/gcp
   ```

   Or with Nickel directly:

   ```bash
   mkdir -p generated/gcp
   docker run --rm -v "$(pwd):/work" -w /work ghcr.io/tweag/nickel:1.10.0 export nickel/targets/gcp.ncl --format yaml > generated/gcp/stack.yaml
   ```

2. **Configure kubectl for your GKE cluster**:

   ```bash
   gcloud container clusters get-credentials <cluster-name> --zone <zone> --project <project-id>
   ```

3. **Apply the stack**:

   ```bash
   kubectl apply -f generated/gcp/stack.yaml
   ```

4. **Check resources and expose Kibana** (e.g. LoadBalancer / Ingress):

   ```bash
   kubectl -n elastic get pods,svc
   ```

   Add persistence, ingress, and secret management (e.g. Secret Manager) as required for your setup.

---

## Summary

| Target       | Generate command (script)              | Deploy | Access Kibana |
|-------------|----------------------------------------|--------|----------------|
| Local Docker| `./scripts/nickel-export.sh local-docker .` or `generated` | Copy `.env` then `./elastic-container.sh start` | **https://**localhost:5601 |
| Minikube    | `./scripts/nickel-export.sh minikube generated/minikube`  | Run `./scripts/generate-k8s-tls-certs.sh`, then `minikube start` and `kubectl apply -f generated/minikube/stack.yaml` | **https://**localhost:5601 after port-forward (accept self-signed cert) |
| AWS (EKS)   | `./scripts/nickel-export.sh aws generated/aws`             | Run cert script, then `kubectl apply -f generated/aws/stack.yaml` | **https://** (TLS; expose via LoadBalancer/Ingress as needed) |
| GCP (GKE)   | `./scripts/nickel-export.sh gcp generated/gcp`             | Run cert script, then `kubectl apply -f generated/gcp/stack.yaml` | **https://** (TLS; expose via LoadBalancer/Ingress as needed) |

The Kubernetes targets produce an Elasticsearch + Kibana stack with TLS and a Secret for credentials. Run `./scripts/generate-k8s-tls-certs.sh` once before applying the stack. Treat the manifests as a starting point and adapt storage, ingress, and secrets to your cluster.
