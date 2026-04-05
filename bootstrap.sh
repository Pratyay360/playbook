#!/bin/sh
# Bootstrap — detects OS, installs Ansible, then runs ansible-pull.
# One-liner usage:
#   curl -fsSL https://raw.githubusercontent.com/pratyay360/playbook/main/bootstrap.sh | sh

set -eu

REPO_URL="${ANSIBLE_REPO_URL:-https://github.com/pratyay360/playbook.git}"
BRANCH="${ANSIBLE_BRANCH:-main}"
PLAYBOOK="${ANSIBLE_PLAYBOOK:-site.yml}"

install_ansible() {
  if command -v ansible-pull >/dev/null 2>&1; then
    echo "==> ansible already installed, skipping."
    return
  fi

  echo "==> Detecting OS..."

  # Debian / Ubuntu
  if command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update -qq
    sudo apt-get install -y ansible

  # Fedora / RHEL / CentOS
  elif command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y epel-release && sudo dnf -y update
    sudo dnf install -y ansible

  # Older RHEL/CentOS
  elif command -v yum >/dev/null 2>&1; then
    sudo yum install -y epel-release
    sudo yum install -y ansible

  # Arch Linux
  elif command -v pacman >/dev/null 2>&1; then
    sudo pacman -Sy --noconfirm ansible

  # openSUSE
  elif command -v zypper >/dev/null 2>&1; then
    sudo zypper install -y ansible

  # Alpine
  elif command -v apk >/dev/null 2>&1; then
    sudo apk add --no-cache ansible

  # Gentoo
  elif command -v emerge >/dev/null 2>&1; then
    sudo emerge --ask=n app-admin/ansible

  # FreeBSD
  elif command -v pkg >/dev/null 2>&1; then
    sudo pkg install -y py311-ansible

  # macOS (Homebrew)
  elif command -v brew >/dev/null 2>&1; then
    brew install ansible

  # Fallback: pipx
  elif command -v pipx >/dev/null 2>&1; then
    pipx install ansible-core

  # Last resort: pip
  elif command -v pip3 >/dev/null 2>&1; then
    pip3 install --user ansible-core

  else
    echo "ERROR: Could not detect a supported package manager. Install ansible manually." >&2
    exit 1
  fi
}

install_ansible

echo "==> Running ansible-pull from ${REPO_URL} (branch: ${BRANCH})..."
ansible-pull \
  --url "${REPO_URL}" \
  --checkout "${BRANCH}" \
  --inventory localhost, \
  --connection local \
  "${PLAYBOOK}"
