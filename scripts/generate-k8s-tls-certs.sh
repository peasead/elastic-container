#!/usr/bin/env bash
# Generate self-signed TLS certs for Elasticsearch and Kibana and create Kubernetes
# Secrets in the elastic namespace. Run this once before applying the Nickel-generated
# K8s stack (minikube/aws/gcp) so that TLS is enabled.
# Requires: openssl, kubectl, namespace "elastic" (create it first or let the script create it).

set -euo pipefail

NAMESPACE="${NAMESPACE:-elastic}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CERT_DIR="${CERT_DIR:-$(mktemp -d)}"

cleanup() { rm -rf "$CERT_DIR"; }
trap cleanup EXIT

echo "Using cert dir: $CERT_DIR"
cd "$CERT_DIR"

# Ensure namespace exists
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

# CA
openssl genrsa -out ca.key 2048
openssl req -x509 -new -nodes -key ca.key -sha256 -days 365 -out ca.crt \
  -subj "/CN=elastic-stack-ca"

# SAN for Elasticsearch and Kibana (localhost for port-forward, K8s DNS for in-cluster)
SAN_ES="DNS:ecp-elasticsearch,DNS:ecp-elasticsearch.$NAMESPACE.svc,DNS:ecp-elasticsearch.$NAMESPACE.svc.cluster.local,DNS:localhost,IP:127.0.0.1"
SAN_KIBANA="DNS:ecp-kibana,DNS:ecp-kibana.$NAMESPACE.svc,DNS:ecp-kibana.$NAMESPACE.svc.cluster.local,DNS:localhost,IP:127.0.0.1"

# Elasticsearch cert
openssl genrsa -out elasticsearch.key 2048
openssl req -new -key elasticsearch.key -out elasticsearch.csr -subj "/CN=ecp-elasticsearch"
openssl x509 -req -in elasticsearch.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
  -out elasticsearch.crt -days 365 -sha256 \
  -extfile <(printf "subjectAltName=%s\n" "$SAN_ES")
cat elasticsearch.crt ca.crt > elasticsearch.chain.pem

# Kibana cert
openssl genrsa -out kibana.key 2048
openssl req -new -key kibana.key -out kibana.csr -subj "/CN=ecp-kibana"
openssl x509 -req -in kibana.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
  -out kibana.crt -days 365 -sha256 \
  -extfile <(printf "subjectAltName=%s\n" "$SAN_KIBANA")

# Create Kubernetes secrets (same key names the Nickel-generated deployments expect)
kubectl create secret generic elasticsearch-certs -n "$NAMESPACE" \
  --from-file=ca.crt=ca.crt \
  --from-file=tls.crt=elasticsearch.crt \
  --from-file=tls.key=elasticsearch.key \
  --from-file=chain.pem=elasticsearch.chain.pem \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic kibana-certs -n "$NAMESPACE" \
  --from-file=ca.crt=ca.crt \
  --from-file=tls.crt=kibana.crt \
  --from-file=tls.key=kibana.key \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Created secrets elasticsearch-certs and kibana-certs in namespace $NAMESPACE."
echo "You can now apply the Nickel-generated stack (e.g. kubectl apply -f generated/minikube/stack.yaml)."
echo "Access Kibana at https://localhost:5601 (after port-forward). Accept the self-signed cert in your browser."
