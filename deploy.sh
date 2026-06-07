#!/usr/bin/env bash
#
# deploy.sh — build the application images and push them to Docker Hub.
#
# Pushes two images:
#   ${DOCKER_USER}/keycloak-be:latest   (Spring Boot identity microservice)
#   ${DOCKER_USER}/web-app:latest       (React frontend served by nginx)
#
# Keycloak and MongoDB are pulled from public registries at runtime
# (see docker-compose.yml) and are NOT built or pushed here.
#
# Usage:
#   export DOCKER_USER=yourdockerhubname
#   ./deploy.sh                 # build + push both images
#   ./deploy.sh build           # build only, do not push
#   ./deploy.sh push            # push only (assumes images already built)
#
# Optional non-interactive login:
#   export DOCKER_USER=yourdockerhubname
#   export DOCKER_PASSWORD=...        # a Docker Hub access token is recommended
#   ./deploy.sh
#
set -euo pipefail

# ---- Configuration ---------------------------------------------------------
REGISTRY="${REGISTRY:-docker.io}"          # override to use a different registry
TAG="${TAG:-latest}"                        # latest-only by request
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Image name -> build context (relative to this script)
BACKEND_IMAGE="keycloak-be"
BACKEND_CONTEXT="${SCRIPT_DIR}/keycloak-be"
FRONTEND_IMAGE="web-app"
FRONTEND_CONTEXT="${SCRIPT_DIR}/web-app"

ACTION="${1:-all}"   # all | build | push

# ---- Helpers ---------------------------------------------------------------
log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
err()  { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; }
die()  { err "$*"; exit 1; }

require_docker_user() {
  [ -n "${DOCKER_USER:-}" ] || die "DOCKER_USER is not set. Run: export DOCKER_USER=yourdockerhubname"
}

full_ref() {
  # full_ref <image> -> registry/user/image:tag (omit registry prefix for default docker.io)
  local image="$1"
  if [ "${REGISTRY}" = "docker.io" ]; then
    printf '%s/%s:%s' "${DOCKER_USER}" "${image}" "${TAG}"
  else
    printf '%s/%s/%s:%s' "${REGISTRY}" "${DOCKER_USER}" "${image}" "${TAG}"
  fi
}

# ---- Steps -----------------------------------------------------------------
docker_login() {
  log "Logging in to ${REGISTRY} as ${DOCKER_USER}"
  if [ -n "${DOCKER_PASSWORD:-}" ]; then
    printf '%s' "${DOCKER_PASSWORD}" | docker login "${REGISTRY}" -u "${DOCKER_USER}" --password-stdin
  else
    docker login "${REGISTRY}" -u "${DOCKER_USER}"
  fi
}

build_images() {
  local be_ref fe_ref
  be_ref="$(full_ref "${BACKEND_IMAGE}")"
  fe_ref="$(full_ref "${FRONTEND_IMAGE}")"

  log "Building backend image: ${be_ref}"
  docker build -t "${be_ref}" "${BACKEND_CONTEXT}"

  log "Building frontend image: ${fe_ref}"
  docker build -t "${fe_ref}" "${FRONTEND_CONTEXT}"

  log "Build complete."
}

push_images() {
  local be_ref fe_ref
  be_ref="$(full_ref "${BACKEND_IMAGE}")"
  fe_ref="$(full_ref "${FRONTEND_IMAGE}")"

  log "Pushing ${be_ref}"
  docker push "${be_ref}"

  log "Pushing ${fe_ref}"
  docker push "${fe_ref}"

  log "Push complete."
  log "Images available at:"
  log "  ${be_ref}"
  log "  ${fe_ref}"
}

# ---- Main ------------------------------------------------------------------
command -v docker >/dev/null 2>&1 || die "docker is not installed or not on PATH."
require_docker_user

case "${ACTION}" in
  build)
    build_images
    ;;
  push)
    docker_login
    push_images
    ;;
  all)
    build_images
    docker_login
    push_images
    ;;
  *)
    die "Unknown action '${ACTION}'. Use one of: all | build | push"
    ;;
esac
