#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

readonly FREETZ_DIR="freetz-ng"
readonly UPSTREAM_URL="https://github.com/Freetz-NG/freetz-ng.git"
readonly CONFIG_FILE="configs/my-box.config"
readonly PATCH_FILE="patches/my_patch.diff"
readonly REQUIRED_TOOLS=("git" "curl" "patch")


determine_package_manager() {
  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    if command -v apt-get &>/dev/null || command -v apt &>/dev/null; then
      readonly SYS_PKG_MGR="apt"
      return 0
    fi
    if command -v dnf &>/dev/null; then
      readonly SYS_PKG_MGR="dnf"
      return 0
    fi
    if command -v yum &>/dev/null; then
      readonly SYS_PKG_MGR="yum"
      return 0
    fi
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    if command -v brew &>/dev/null; then
      readonly SYS_PKG_MGR="brew"
      return 0
    fi
  elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" || "$OSTYPE" == "cygwin" ]]; then
    echo "💀 How did you get here?"
    exit 1
  fi
  
  echo "❌ Unable to determine package manager. Please install the following tools manually:"
  printf "   - %s\n" "${REQUIRED_TOOLS[@]}"
  exit 1
}

install_dependencies() {
  local missing_tools=()
  
  for tool in "${REQUIRED_TOOLS[@]}"; do
    if ! command -v "$tool" &>/dev/null; then
      missing_tools+=("$tool")
    fi
  done
  
  if [[ ${#missing_tools[@]} -eq 0 ]]; then
    return 0
  fi
  
  echo "🔍 Missing required tools: ${missing_tools[*]}"
  echo "📦 Attempting to install..."
  
  case "$SYS_PKG_MGR" in
    apt)
      for tool in "${missing_tools[@]}"; do
        if ! sudo apt-get update -qq && sudo apt-get install -y "$tool"; then
          # Try snap as fallback
          if [[ "$tool" != "snap" ]]; then
            if ! command -v snap &>/dev/null; then
              echo "📦 Installing snap package manager..."
              if ! sudo apt-get install -y snapd; then
                echo "❌ Failed to install snap. Cannot install $tool."
                exit 1
              fi
            fi
            echo "📦 Attempting to install $tool via snap..."
            if ! sudo snap install "$tool"; then
              echo "❌ Failed to install $tool via apt-get and snap."
              exit 1
            fi
          else
            echo "❌ Failed to install $tool."
            exit 1
          fi
        fi
      done
      ;;
    brew)
      for tool in "${missing_tools[@]}"; do
        if ! brew install "$tool"; then
          echo "❌ Failed to install $tool via Homebrew."
          exit 1
        fi
      done
      ;;
    dnf|yum)
      for tool in "${missing_tools[@]}"; do
        if ! sudo "$SYS_PKG_MGR" install -y "$tool"; then
          echo "❌ Failed to install $tool via $SYS_PKG_MGR."
          exit 1
        fi
      done
      ;;
  esac
  
  # Verify installations
  for tool in "${missing_tools[@]}"; do
    if ! command -v "$tool" &>/dev/null; then
      echo "❌ Failed to install required tool: $tool"
      echo "Please install it manually and try again."
      exit 1
    fi
  done
  
  echo "✅ All dependencies installed successfully."
}

fetch_latest_commit() {
  git fetch origin upstream-state
  git show origin/upstream-state:last_commit.txt > .last_upstream_commit 2>/dev/null || echo "" > .last_upstream_commit
  readonly LATEST_COMMIT=$(git ls-remote "${UPSTREAM_URL}" refs/heads/master | cut -f1)
  readonly LAST_COMMIT=$(cat .last_upstream_commit)
}

check_for_changes() {
  if [[ "${LAST_COMMIT}" == "${LATEST_COMMIT}" ]]; then
    echo "🔁 No new upstream commit. Build skipped."
    exit 0
  fi
}

setup_repository() {
  if [[ ! -d "${FREETZ_DIR}" ]]; then
    git clone "${UPSTREAM_URL}" "${FREETZ_DIR}"
  else
    pushd "${FREETZ_DIR}" > /dev/null
    git reset --hard
    git clean -fd
    git pull origin master
    popd > /dev/null
  fi
}

apply_config_and_patch() {
  cp "${CONFIG_FILE}" "${FREETZ_DIR}/.config"
  
  if [[ -f "${PATCH_FILE}" ]]; then
    patch -d "${FREETZ_DIR}" -p1 < "${PATCH_FILE}" || true
  fi
}

build_firmware() {
  pushd "${FREETZ_DIR}" > /dev/null
  make oldconfig
  make -j"$(nproc)"
  popd > /dev/null
}

rename_firmware() {
  pushd "${FREETZ_DIR}" > /dev/null
  readonly FIRMWARE_OUT=$(ls images/*.image 2>/dev/null | head -n 1)
  if [[ -n "${FIRMWARE_OUT}" ]]; then
    readonly VERSION_TAG=${LATEST_COMMIT:0:7}
    readonly NEW_NAME="fritzbox-firmware-${VERSION_TAG}.image"
    mv "${FIRMWARE_OUT}" "images/${NEW_NAME}"
  fi
  popd > /dev/null
}

update_commit_state() {
  echo "${LATEST_COMMIT}" > last_commit.txt
  git config user.email "${GH_EMAIL_ADDRESS}"
  git config user.name "CI Bot"
  git checkout --orphan upstream-temp
  git add last_commit.txt
  git commit -m "Update last upstream commit to ${LATEST_COMMIT:0:7}"
  git push -f origin HEAD:upstream-state
  git checkout main
}

send_notifications() {
  # VERSION_TAG=${LATEST_COMMIT:0:7}
  readonly SUCCESS_MESSAGE="✅ New Freetz-NG build successful (Commit ${VERSION_TAG})"
  
  if [[ -n "${TELEGRAM_TOKEN:-}" && -n "${TELEGRAM_CHAT_ID:-}" ]]; then
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
      -d chat_id="${TELEGRAM_CHAT_ID}" \
      -d text="${SUCCESS_MESSAGE}"
  fi
  
  if [[ -n "${DISCORD_WEBHOOK:-}" ]]; then
    curl -H "Content-Type: application/json" -X POST \
      -d "{\"content\": \"${SUCCESS_MESSAGE}\"}" \
      "${DISCORD_WEBHOOK}"
  fi
  
  if [[ -n "${MATTERMOST_WEBHOOK:-}" ]]; then
    curl -X POST -H "Content-Type: application/json" \
      -d "{\"text\": \"${SUCCESS_MESSAGE}\"}" \
      "${MATTERMOST_WEBHOOK}"
  fi
}

main() {
  determine_package_manager
  install_dependencies
  fetch_latest_commit
  check_for_changes
  setup_repository
  apply_config_and_patch
  build_firmware
  rename_firmware
  update_commit_state
  send_notifications
}

main "$@"