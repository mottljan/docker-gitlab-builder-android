# === Global args ===

# == Versions ==

ARG ANDROID_CMDLINE_TOOLS_VERSION="14742923"

ARG DANGER_JS_VERSION="12.3.4"
ARG DANGER_KOTLIN_VERSION="1.3.4"
ARG DANGER_KOTLIN_CHECKSUM="sha256:232b11680cdfe50c64a6cef1d96d3cd09a857422da1e2dd0464f80c8ddb1afac"

# JAVA_VERSION selects both the Temurin base image tag (`<version>-jdk`) and the JAVA_HOME dir name.
ARG JAVA_VERSION="21.0.11_10"

# Needed for danger-kotlin
ARG KOTLINC_VERSION="2.4.0"
ARG KOTLINC_CHECKSUM="sha256:ba1b9e6eb6ddc3275079224f2e9ea4a2b02eef7d59ce2d38404f04b22613c20a"

# == Others ==

ARG CMDLINE_TOOLS_DIR="cmdline-tools"
ARG CMDLINE_TOOLS_VERSION_DIR="latest"

ARG DANGER_BASE_PATH="/usr/local"
ARG KOTLINC_BASE_PATH="/usr/lib"



# === Stages ===

# == base ==

# Base stage that all stages inherit from. It contains common setup needed for both build and final stages.
FROM dhi.io/debian-base:trixie-debian13-dev AS base

ARG CMDLINE_TOOLS_DIR
ARG CMDLINE_TOOLS_VERSION_DIR
ARG JAVA_VERSION

SHELL ["/bin/bash", "-c"]

ENV ANDROID_HOME="/opt/android-sdk"
ENV PATH="$PATH:$ANDROID_HOME/$CMDLINE_TOOLS_DIR/$CMDLINE_TOOLS_VERSION_DIR"
ENV PATH="$PATH:$ANDROID_HOME/$CMDLINE_TOOLS_DIR/$CMDLINE_TOOLS_VERSION_DIR/bin"
ENV PATH="$PATH:$ANDROID_HOME/platform-tools"

ENV JAVA_HOME="/usr/lib/jdk/$JAVA_VERSION"
ENV PATH="$PATH:$JAVA_HOME/bin"

RUN apt update && apt install -y --no-install-recommends \
    git \
    && rm -rf /var/lib/apt/lists/*



# == build ==

# Base stage for all build stages. These stages are used for building dependencies that are then
# copied to the final image.
FROM base AS build

RUN apt update && apt install -y --no-install-recommends \
    curl \
    # Needed for danger-js installation
    npm \
    unzip

# Disables npm preinstall, postintall and other scripts that might run when any npm package is installed,
# which is usually exploited by supply chain attacks like shai-hulud. Set via ENV rather than
# `npm config set` so it applies to every user (incl. the nonroot install in danger-installation),
# instead of being written to a single user's ~/.npmrc that a USER switch would bypass.
ENV npm_config_ignore_scripts=true



# == java-installation ==

# The JDK is copied from Adoptium's official Temurin image instead of downloading and unpacking the
# tarball ourselves. `ADD --unpack` corrupts the large (~142MB) Java 21 module image when the build
# runs under QEMU emulation (e.g. building linux/amd64 on Apple Silicon): lib/modules ends up with
# zero-filled pages and fails at runtime with "ClassFormatError: Incompatible magic value 0".
# COPY --from is a native BuildKit op that copies the pre-extracted, known-good bytes.
FROM eclipse-temurin:${JAVA_VERSION}-jdk AS temurin-jdk

FROM build AS java-installation
COPY --from=temurin-jdk /opt/java/openjdk "$JAVA_HOME"



# == android-sdk-installation ==

# Installs Android SDK. Requires Java to be already installed.
FROM java-installation AS android-sdk-installation

ARG ANDROID_CMDLINE_TOOLS_VERSION
ARG CMDLINE_TOOLS_DIR
ARG CMDLINE_TOOLS_VERSION_DIR

WORKDIR /opt

ARG CMDLINE_TOOLS_ZIP="cmdline-tools.zip"
ADD "https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_CMDLINE_TOOLS_VERSION}_latest.zip" \
    "./$CMDLINE_TOOLS_ZIP"

ARG CMDLINE_TOOLS_PATH="$ANDROID_HOME/$CMDLINE_TOOLS_DIR"
RUN mkdir -p "$CMDLINE_TOOLS_PATH" && \
    unzip -q "$CMDLINE_TOOLS_ZIP" -d "$CMDLINE_TOOLS_PATH" && \
    mv "$CMDLINE_TOOLS_PATH/$CMDLINE_TOOLS_DIR" "$CMDLINE_TOOLS_PATH/$CMDLINE_TOOLS_VERSION_DIR"

# Accept licenses before installing components
# License is valid for all the standard components in versions installed from this file
# Non-standard components: MIPS system images, preview versions, GDK (Google Glass) and Android Google TV require separate licenses, not accepted there
RUN yes | sdkmanager --licenses
RUN sdkmanager "platform-tools"



# == danger-installation ==

FROM build AS danger-installation

ARG DANGER_BASE_PATH
ARG DANGER_JS_VERSION
ARG DANGER_KOTLIN_VERSION
ARG DANGER_KOTLIN_CHECKSUM
ARG KOTLINC_BASE_PATH
ARG KOTLINC_CHECKSUM
ARG KOTLINC_VERSION

# Recent hardened Debian base images removed /usr/local, so we need to create it ourselves
RUN mkdir -p "$DANGER_BASE_PATH"
# chown of directories where danger will be installed, so nonroot npm process can write there
RUN chown -R nonroot:nonroot "$DANGER_BASE_PATH"
# Recent hardened Debian base images no longer pin npm's global prefix to /usr/local, so npm
# defaults to /usr (installs to /usr/lib/node_modules, not writable by nonroot). Pin it back to
# $DANGER_BASE_PATH so `npm install -g` and `npm root -g` target the chowned, expected location.
ENV npm_config_prefix="$DANGER_BASE_PATH"
# Change to nonroot user for npm install to reduce attack surface if compromised
USER nonroot

# Install danger JS that is needed for danger-kotlin
RUN npm install -g "danger@$DANGER_JS_VERSION"
# Solves dockle's DKL-LI-0003 reported issue to remove unnecessary files
RUN rm -f "$DANGER_BASE_PATH/lib/node_modules/danger/Dockerfile"

# Clone and run shai-hulud-detector script that checks for shai-hulud supply chain attacks
WORKDIR /tmp
RUN git clone https://github.com/Cobenian/shai-hulud-detect
# Allows user to override shai-hulud detector mode. Useful for running --paranoid mode on CI, which
# takes longer but is more secure and checks even for other malicious behaviour other than shai-hulud.
ARG SHAI_HULUD_DETECTOR_MODE=""
RUN ./shai-hulud-detect/shai-hulud-detector.sh "$SHAI_HULUD_DETECTOR_MODE" "$(npm root -g)"; \
    exit_code=$?; \
    case "$exit_code" in \
        # Succeed on medium-risk issues found (2)
        2) exit 0 ;; \
        # Fail on high-risk issues found (1), succeed (0) or fail with anything else
        *) exit "$exit_code" ;; \
    esac

# Switch back to root to finish Danger installation
USER root

# Install Kotlin compiler
ARG COMPILER_ZIP="kotlin-compiler.zip"
ADD --checksum="$KOTLINC_CHECKSUM" \
    "https://github.com/JetBrains/kotlin/releases/download/v$KOTLINC_VERSION/kotlin-compiler-$KOTLINC_VERSION.zip" \
    "./$COMPILER_ZIP"
RUN unzip "$COMPILER_ZIP" -d "$KOTLINC_BASE_PATH"

# Install danger-kotlin
ADD --checksum="$DANGER_KOTLIN_CHECKSUM" --unpack=true \
    "https://github.com/danger/kotlin/releases/download/$DANGER_KOTLIN_VERSION/danger-kotlin-linuxX64.tar" \
    "$DANGER_BASE_PATH"



# == git-lfs-installation ==

FROM build AS git-lfs-installation

RUN curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh | bash && \
    apt update && apt install -y --no-install-recommends git-lfs



# == final ==

# Final stage of the image build process. This is the only stage that is kept in the final image.
# This should mainly copy prepared binaries from other stages.
FROM base AS final

ARG DANGER_BASE_PATH
ARG KOTLINC_BASE_PATH

LABEL tag="ackee-gitlab" \
      author="Ackee 🦄" \
      description="This Docker image serves as an environment for running Android builds on Gitlab CI in Ackee workspace"

RUN apt update && apt install -y --no-install-recommends \
    # Needed for EasyLauncher
    fontconfig \
    # Needed for danger-js
    nodejs \
    && rm -rf /var/lib/apt/lists/*

COPY --from=java-installation "$JAVA_HOME" "$JAVA_HOME"

COPY --from=android-sdk-installation "$ANDROID_HOME" "$ANDROID_HOME"
# Allows nonroot user to modify Android SDK folders, e.g. download new build tools/platforms
RUN chown -R nonroot:nonroot "$ANDROID_HOME"

# Danger binaries
ARG DANGER_BIN_PATH="$DANGER_BASE_PATH/bin"
COPY --from=danger-installation "$DANGER_BIN_PATH" "$DANGER_BIN_PATH"

ARG DANGER_LIB_PATH="$DANGER_BASE_PATH/lib"

# Danger JS node_modules dependencies
ARG DANGER_NODE_MODULES_PATH="$DANGER_LIB_PATH/node_modules"
COPY --from=danger-installation "$DANGER_NODE_MODULES_PATH" "$DANGER_NODE_MODULES_PATH"

# danger-kotlin libs
ARG DANGER_KOTLIN_LIB_PATH="$DANGER_LIB_PATH/danger"
COPY --from=danger-installation "$DANGER_KOTLIN_LIB_PATH" "$DANGER_KOTLIN_LIB_PATH"

COPY --from=danger-installation "$KOTLINC_BASE_PATH" "$KOTLINC_BASE_PATH"
ENV PATH="$PATH:$KOTLINC_BASE_PATH/kotlinc/bin"

ARG GIT_LFS_PATH="/usr/bin/git-lfs"
COPY --from=git-lfs-installation "$GIT_LFS_PATH" "$GIT_LFS_PATH"
RUN git lfs install

# Remove binaries that might allow privilege escalation
RUN rm -f /bin/su
RUN rm -f /usr/bin/apt /usr/bin/apt-get /usr/bin/apt-cache
RUN rm -f /usr/bin/dpkg
RUN rm -f /usr/sbin/unix_chkpwd

USER nonroot
