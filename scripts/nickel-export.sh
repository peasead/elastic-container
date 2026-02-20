#!/usr/bin/env bash
# Generate deployment artifacts using Nickel.
# Requires: Docker (to run Nickel), jq (for local-docker .env conversion).
# Run from repo root: ./scripts/nickel-export.sh [target] [outdir]
# Targets: local-docker, minikube, aws, gcp

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# Use Nickel via Docker so no local install is required
NICKEL_CMD="docker run --rm -v \"${REPO_ROOT}:/work\" -w /work ghcr.io/tweag/nickel:1.10.0 export"

target="${1:-}"
outdir="${2:-generated}"

usage() {
  echo "Usage: $0 <target> [outdir]"
  echo "  target: local-docker | minikube | aws | gcp"
  echo "  outdir: output directory (default: generated). Use - to only print (local-docker), . to write repo root .env"
  echo ""
  echo "Examples:"
  echo "  $0 local-docker              # print .env to stdout and write generated/.env"
  echo "  $0 local-docker -            # print .env to stdout only"
  echo "  $0 local-docker .            # print and write .env in repo root (backup existing .env first)"
  echo "  $0 minikube generated/minikube"
  echo "  $0 aws generated/aws"
  echo "  $0 gcp generated/gcp"
  exit 1
}

run_nickel() {
  local file="$1"
  local fmt="${2:-json}"
  eval "$NICKEL_CMD" "$file" --format "$fmt" "$@"
}

case "$target" in
  local-docker)
    if ! command -v jq &>/dev/null; then
      echo "jq is required for local-docker target. Install jq or run Nickel manually:"
      echo "  $NICKEL_CMD nickel/targets/local-docker.ncl --format json"
      exit 1
    fi
    # Export config as JSON and convert to .env format (KEY=value)
    run_nickel "nickel/targets/local-docker.ncl" "json" \
      | jq -r 'to_entries | .[] | "\(.key)=\(.value)"'
    if [ -n "${outdir}" ] && [ "$outdir" != "-" ] && [ "$outdir" != "." ]; then
      mkdir -p "$outdir"
      run_nickel "nickel/targets/local-docker.ncl" "json" \
        | jq -r 'to_entries | .[] | "\(.key)=\(.value)"' > "$outdir/.env"
      echo "Wrote $outdir/.env" >&2
    fi
    ;;
  minikube|aws|gcp)
    mkdir -p "$outdir"
    outfile="$outdir/stack.yaml"
    run_nickel "nickel/targets/${target}.ncl" "yaml" > "$outfile"
    echo "Wrote $outfile" >&2
    ;;
  "")
    usage
    ;;
  *)
    echo "Unknown target: $target" >&2
    usage
    ;;
esac
