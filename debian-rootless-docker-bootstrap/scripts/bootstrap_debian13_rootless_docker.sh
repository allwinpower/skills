#!/usr/bin/env bash
set -euo pipefail

ADMIN_USER="${ADMIN_USER:-admin}"
BOOTSTRAP_USER="${BOOTSTRAP_USER:-${SUDO_USER:-}}"
REMOVE_BOOTSTRAP_USER="${REMOVE_BOOTSTRAP_USER:-no}"
DELETE_BOOTSTRAP_HOME="${DELETE_BOOTSTRAP_HOME:-yes}"
ALLOW_LOW_PORTS="${ALLOW_LOW_PORTS:-yes}"
DEFAULT_ADMIN_SSH_PUBKEYS="${DEFAULT_ADMIN_SSH_PUBKEYS:-ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOvNI10a8cqHLy+X3XbodaiMx8RMfXx/HDbcD03zrqT8
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFGf+oyDlpCQ+58vymJIWiXoOuW7hwqu4R7iOvLItfYX}"
ADMIN_SSH_PUBKEY="${ADMIN_SSH_PUBKEY:-}"
ADMIN_EXTRA_SSH_PUBKEYS="${ADMIN_EXTRA_SSH_PUBKEYS:-}"
SUDO_AUTHORIZED_PUBKEY="${SUDO_AUTHORIZED_PUBKEY:-}"

log() {
  printf '[bootstrap] %s\n' "$*"
}

fail() {
  printf '[bootstrap] ERROR: %s\n' "$*" >&2
  exit 1
}

require_root() {
  [ "$(id -u)" -eq 0 ] || fail "run as root or with sudo"
}

require_debian_13() {
  . /etc/os-release
  [ "${ID:-}" = "debian" ] || fail "expected Debian, found ${ID:-unknown}"
  [ "${VERSION_CODENAME:-}" = "trixie" ] || fail "expected Debian 13 trixie, found ${VERSION_CODENAME:-unknown}"
}

require_inputs() {
  [ "$ADMIN_USER" != "root" ] || fail "ADMIN_USER cannot be root"
  [ -n "$(admin_authorized_keys)" ] || fail "set DEFAULT_ADMIN_SSH_PUBKEYS, ADMIN_SSH_PUBKEY, or ADMIN_EXTRA_SSH_PUBKEYS"
}

unique_key_lines() {
  awk 'NF && $1 !~ /^#/ && !seen[$0]++'
}

admin_authorized_keys() {
  {
    printf '%s\n' "$DEFAULT_ADMIN_SSH_PUBKEYS"
    printf '%s\n' "$ADMIN_SSH_PUBKEY"
    printf '%s\n' "$ADMIN_EXTRA_SSH_PUBKEYS"
  } | unique_key_lines
}

sudo_authorized_keys() {
  if [ -n "$SUDO_AUTHORIZED_PUBKEY" ]; then
    printf '%s\n' "$SUDO_AUTHORIZED_PUBKEY" | unique_key_lines
  else
    admin_authorized_keys
  fi
}

apt_update_upgrade() {
  log "updating Debian packages"
  export DEBIAN_FRONTEND=noninteractive
  apt-get update
  apt-get -y full-upgrade
  apt-get -y install ca-certificates curl gnupg openssl openssh-server sudo uidmap dbus-user-session slirp4netns fuse-overlayfs libcap2-bin libpam-ssh-agent-auth
}

install_docker_official() {
  log "installing Docker from official Debian repository"
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --batch --yes --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
  . /etc/os-release
  printf 'deb [arch=%s signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian %s stable\n' \
    "$(dpkg --print-architecture)" "$VERSION_CODENAME" > /etc/apt/sources.list.d/docker.list
  apt-get update
  apt-get -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker-ce-rootless-extras
}

create_admin_user() {
  log "creating ${ADMIN_USER}"
  if ! id "$ADMIN_USER" >/dev/null 2>&1; then
    useradd -m -s /bin/bash "$ADMIN_USER"
  fi
  local random_hash
  random_hash="$(openssl passwd -6 "$(openssl rand -base64 32)")"
  usermod -p "$random_hash" "$ADMIN_USER"
  usermod -aG sudo "$ADMIN_USER"

  local home
  home="$(getent passwd "$ADMIN_USER" | cut -d: -f6)"
  install -d -m 0700 -o "$ADMIN_USER" -g "$ADMIN_USER" "$home/.ssh"
  admin_authorized_keys > "$home/.ssh/authorized_keys"
  chown "$ADMIN_USER:$ADMIN_USER" "$home/.ssh/authorized_keys"
  chmod 0600 "$home/.ssh/authorized_keys"
}

ensure_subids() {
  log "ensuring subordinate uid/gid ranges"
  grep -q "^${ADMIN_USER}:" /etc/subuid || printf '%s:100000:65536\n' "$ADMIN_USER" >> /etc/subuid
  grep -q "^${ADMIN_USER}:" /etc/subgid || printf '%s:100000:65536\n' "$ADMIN_USER" >> /etc/subgid
}

configure_sudo_ssh_agent() {
  log "configuring SSH-agent-backed sudo"
  sudo_authorized_keys > /etc/security/sudo_authorized_keys
  chown root:root /etc/security/sudo_authorized_keys
  chmod 0644 /etc/security/sudo_authorized_keys

  if ! grep -q 'pam_ssh_agent_auth.so' /etc/pam.d/sudo; then
    cp /etc/pam.d/sudo "/etc/pam.d/sudo.before-ssh-agent-auth.$(date +%Y%m%d%H%M%S)"
    sed -i '1aauth sufficient pam_ssh_agent_auth.so file=/etc/security/sudo_authorized_keys' /etc/pam.d/sudo
  fi

  cat > "/etc/sudoers.d/90-${ADMIN_USER}-ssh-agent" <<EOF
Defaults env_keep += "SSH_AUTH_SOCK"
Defaults:${ADMIN_USER} timestamp_timeout=0
${ADMIN_USER} ALL=(ALL:ALL) ALL
EOF
  chmod 0440 "/etc/sudoers.d/90-${ADMIN_USER}-ssh-agent"
  visudo -cf "/etc/sudoers.d/90-${ADMIN_USER}-ssh-agent" >/dev/null
}

configure_sshd() {
  log "configuring admin-only SSH"
  cat > /etc/ssh/sshd_config.d/99-admin-only.conf <<EOF
AllowUsers ${ADMIN_USER}
PermitRootLogin no
PubkeyAuthentication yes
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitEmptyPasswords no
UsePAM yes
AllowAgentForwarding yes
EOF
  sshd -t
  systemctl reload ssh || systemctl reload sshd
}

install_rootless_docker() {
  log "installing rootless Docker for ${ADMIN_USER}"
  local admin_uid
  local admin_home
  local docker_host
  local user_bus
  admin_uid="$(id -u "$ADMIN_USER")"
  admin_home="$(getent passwd "$ADMIN_USER" | cut -d: -f6)"
  docker_host="unix:///run/user/${admin_uid}/docker.sock"
  user_bus="unix:path=/run/user/${admin_uid}/bus"
  loginctl enable-linger "$ADMIN_USER"
  systemctl start "user@${admin_uid}.service" >/dev/null 2>&1 || true

  local attempt
  for attempt in 1 2 3 4 5; do
    [ -S "/run/user/${admin_uid}/bus" ] && break
    sleep 1
  done

  if [ ! -f "${admin_home}/.config/systemd/user/docker.service" ]; then
    runuser -u "$ADMIN_USER" -- env \
      "XDG_RUNTIME_DIR=/run/user/${admin_uid}" \
      "DBUS_SESSION_BUS_ADDRESS=${user_bus}" \
      "PATH=/usr/bin:/sbin:/usr/sbin:/bin" \
      dockerd-rootless-setuptool.sh install --force
  fi
  runuser -u "$ADMIN_USER" -- env \
    "XDG_RUNTIME_DIR=/run/user/${admin_uid}" \
    "DBUS_SESSION_BUS_ADDRESS=${user_bus}" \
    systemctl --user enable --now docker

  if [ "$ALLOW_LOW_PORTS" = "yes" ]; then
    local rootlesskit
    rootlesskit="$(command -v rootlesskit || true)"
    [ -n "$rootlesskit" ] || fail "rootlesskit not found"
    setcap cap_net_bind_service=ep "$rootlesskit"
  fi

  runuser -u "$ADMIN_USER" -- env \
    "XDG_RUNTIME_DIR=/run/user/${admin_uid}" \
    "DBUS_SESSION_BUS_ADDRESS=${user_bus}" \
    "DOCKER_HOST=${docker_host}" \
    docker info >/dev/null

  runuser -u "$ADMIN_USER" -- env \
    "XDG_RUNTIME_DIR=/run/user/${admin_uid}" \
    "DBUS_SESSION_BUS_ADDRESS=${user_bus}" \
    docker context update rootless --docker "host=${docker_host}" >/dev/null 2>&1 || true
  runuser -u "$ADMIN_USER" -- env \
    "XDG_RUNTIME_DIR=/run/user/${admin_uid}" \
    "DBUS_SESSION_BUS_ADDRESS=${user_bus}" \
    docker context use rootless >/dev/null 2>&1 || true

  mkdir -p "${admin_home}/.config/environment.d"
  printf 'DOCKER_HOST=%s\n' "$docker_host" > "${admin_home}/.config/environment.d/docker.conf"
  if ! grep -q 'DOCKER_HOST=unix:///run/user/' "${admin_home}/.profile" 2>/dev/null; then
    printf '\nexport DOCKER_HOST=%s\n' "$docker_host" >> "${admin_home}/.profile"
  fi
  chown -R "$ADMIN_USER:$ADMIN_USER" "${admin_home}/.config" "${admin_home}/.profile"
}

disable_rootful_docker() {
  log "disabling rootful Docker services"
  systemctl disable --now docker.service docker.socket >/dev/null 2>&1 || true
  systemctl disable --now containerd.service >/dev/null 2>&1 || true
}

verify_admin_local() {
  log "running local verification"
  local admin_uid
  admin_uid="$(id -u "$ADMIN_USER")"
  id "$ADMIN_USER" >/dev/null
  sshd -t
  runuser -u "$ADMIN_USER" -- env "XDG_RUNTIME_DIR=/run/user/${admin_uid}" "DOCKER_HOST=unix:///run/user/${admin_uid}/docker.sock" docker compose version >/dev/null
  runuser -u "$ADMIN_USER" -- env "XDG_RUNTIME_DIR=/run/user/${admin_uid}" "DOCKER_HOST=unix:///run/user/${admin_uid}/docker.sock" docker info --format '{{json .SecurityOptions}}' | grep -q rootless
  ! systemctl is-active --quiet docker.service
  ! systemctl is-active --quiet docker.socket
  ! systemctl is-active --quiet containerd.service
}

remove_bootstrap_user() {
  if [ "$REMOVE_BOOTSTRAP_USER" != "yes" ]; then
    log "bootstrap user removal not requested. After external admin SSH verification, rerun with REMOVE_BOOTSTRAP_USER=yes."
    return
  fi
  if [ -z "$BOOTSTRAP_USER" ] || [ "$BOOTSTRAP_USER" = "root" ] || [ "$BOOTSTRAP_USER" = "$ADMIN_USER" ]; then
    log "skipping bootstrap user removal"
    return
  fi
  if ! id "$BOOTSTRAP_USER" >/dev/null 2>&1; then
    log "bootstrap user ${BOOTSTRAP_USER} does not exist"
    return
  fi

  log "removing bootstrap user ${BOOTSTRAP_USER}"
  gpasswd -d "$BOOTSTRAP_USER" sudo >/dev/null 2>&1 || true
  if [ "$DELETE_BOOTSTRAP_HOME" = "yes" ]; then
    deluser --remove-home "$BOOTSTRAP_USER"
  else
    passwd -l "$BOOTSTRAP_USER" >/dev/null
    usermod -s /usr/sbin/nologin "$BOOTSTRAP_USER"
  fi
}

main() {
  require_root
  require_debian_13
  require_inputs
  apt_update_upgrade
  install_docker_official
  create_admin_user
  ensure_subids
  configure_sudo_ssh_agent
  install_rootless_docker
  disable_rootful_docker
  configure_sshd
  verify_admin_local
  remove_bootstrap_user
  log "complete. Verify from your local machine with: ssh -A -tt ${ADMIN_USER}@HOST 'sudo -k; sudo true; sudo whoami' and ssh -A ${ADMIN_USER}@HOST 'docker info'"
}

main "$@"
