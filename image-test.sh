#!/bin/bash

check_user_not_root() {
  if [ "$(id -u)" -eq 0 ]; then
    echo "User must not be root! 💣" >&2
    exit 1
  else
    echo "User is unprivileged $(whoami) 🔒"
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

check_dir() {
  local dir=$1
  if [[ -d "$dir" ]]; then
    echo "$dir exists ✅"
  else
    echo "Error: directory not found: $dir" >&2
    exit 1
  fi
}

check_dir_writable() {
  local dir=$1
  if test -w "$dir"; then
    echo "$dir writable ✅"
  else
    echo "$dir not writable but must be ❌" >&2
    exit 1
  fi
}

check_env() {
  local var=$1
  if [[ -n ${!var} ]]; then
    echo "$var present ✅"
  else
    echo "Error: env var missing or empty: $var" >&2
    exit 1
  fi
}

# Security
echo
echo "Security check"
check_user_not_root
check_command_missing "apt"
check_command_missing "apt-get"
check_command_missing "dpkg"
check_command_missing "npm"
check_command_missing "su"
check_command_missing "sudo"

# Required custom SW
echo
echo "Required custom SW check"
check_command_exists "git"
check_command_exists "git-lfs"
check_command_exists "java"

check_command_exists "sdkmanager"
check_dir_writable "$ANDROID_HOME"
check_dir "$ANDROID_HOME/cmdline-tools"
check_dir "$ANDROID_HOME/licenses"

check_command_exists "danger"
check_command_exists "danger-kotlin"
check_command_exists "kotlinc" "-version" # Needed for danger-kotlin
check_command_exists "nodejs" # Needed for danger (JS)
check_dir "/usr/local/lib/danger" # Check that danger-kotlin lib exists
check_dir "/usr/local/lib/node_modules/danger" # Check that danger node_modules exists

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

# Build image-test-app
echo
echo "Build image-test-app check"
cd /image-test-app
./gradlew assembleDebug --no-daemon
echo "image-test-app build successful ✅"
