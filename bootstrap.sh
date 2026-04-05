#!/bin/bash
# Bootstrap script — installs ansible and pulls + runs the playbook in one shot.
# Usage on the target server:
#   curl -fsSL https://raw.githubusercontent.com/<your-org>/<your-repo>/main/bootstrap.sh | bash

set -euo pipefail

REPO_URL="${ANSIBLE_REPO_URL:-https://github.com/<your-org>/<your-repo>.git}"
BRANCH="${ANSIBLE_BRANCH:-main}"
PLAYBOOK="${ANSIBLE_PLAYBOOK:-site.yml}"

echo "==> Installing ansible..."
if command -v dnf &>/dev/null; then
  sudo dnf install -y ansible
elif command -v apt-get &>/dev/null; then
  sudo apt-get update -qq && sudo apt-get install -y ansible
else
  echo "Unsupported package manager. Install ansible manually." && exit 1
fi

echo "==> Installing required collections..."
ansible-galaxy collection install -r collections/requirements.yml 2>/dev/null || true

echo "==> Running ansible-pull from ${REPO_URL} (branch: ${BRANCH})..."
ansible-pull \
  --url "${REPO_URL}" \
  --checkout "${BRANCH}" \
  --inventory localhost, \
  --connection local \
  "${PLAYBOOK}"
