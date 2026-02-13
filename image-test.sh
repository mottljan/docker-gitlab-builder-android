#!/bin/bash

check_command_exists() {
  local command=$1
  local default_version_option="--version"
  local version_option="${2:-$default_version_option}"
  if "$command" "$version_option" >/dev/null; then
    echo "$command ✅"
  else
    echo "$command ❌" >&2
    exit 1
  fi
}

check_command_missing() {
  local command=$1
  if command -v "$command" &> /dev/null; then
    echo "$command exists but should not 💣" >&2
    exit 1
  else
    echo "$command is missing 🔒"
  fi
}

check_env() {
    local var=$1
    if [[ -n ${!var} ]]; then
        echo "$var present  ✅"
    else
        echo "Error: env var missing or empty: $var" >&2
        exit 1
    fi
}

check_dir() {
    local dir=$1
    if [[ -d "$dir" ]]; then
        echo "Directory exists: $dir  ✅"
    else
        echo "Error: directory not found: $dir" >&2
        exit 1
    fi
}

check_user_not_root() {
  if [ "$(id -u)" -eq 0 ]; then
    echo "User must not be root! 💣" >&2
    exit 1
  else
    echo "User is unprivileged $(whoami) 🔒"
  fi
}

# Security
echo
echo "Security check"
check_user_not_root
check_command_missing "sudo"
check_command_missing "su"
check_command_missing "apt"
check_command_missing "apt-get"

# Required custom SW
echo
echo "Required custom SW check"
check_command_exists "git"
check_command_exists "git-lfs"
check_command_exists "java"
check_command_exists "sdkmanager"

check_command_exists "danger"
check_command_exists "danger-kotlin"
check_command_exists "kotlinc" "-version" # Needed for danger-kotlin
check_command_exists "nodejs" # Needed for danger (JS)
check_dir "/usr/local/lib/danger" # Check that danger-kotlin lib exists
check_dir "/usr/local/lib/node_modules/danger" # Check that danger node_modules exists

# TODO Add check for build-tools/platforms if they stay in the image

# Commonly used Linux SW on CI
echo
echo "Commonly used Linux SW on CI check"
check_command_exists "awk"
check_command_exists "cat"
check_command_exists "cp"
check_command_exists "grep"
check_command_exists "ln"
check_command_exists "mkdir"
check_command_exists "rm"

# Env vars
echo
echo "Env vars check"
check_env "ANDROID_HOME"
check_env "JAVA_HOME"

# Build app
# TODO
