# TODO write tests script for this image

# TODO Probably create compose file for build and test this image
# TODO Create pipeline for this image
# TODO Test on real CI + try to create self-hosted GitLab + runner a try to test our pipeline with volumes
# TODO Investigate usage of Docker scout for checking vulnarabilities and updates versions
# TODO Document and refactor this file more
# TODO Check agains Docker's build best practices and OWASP security guidelines

# === Versions ===
ARG ANDROID_CMDLINE_TOOLS_VERSION="14742923"
ARG ANDROID_BUILD_TOOLS_VERSION="36.1.0"
ARG ANDROID_PLATFORM_VERSION="36"

ARG DANGER_JS_VERSION="12.3.4"
ARG DANGER_KOTLIN_VERSION="1.3.4"
ARG DANGER_KOTLIN_CHECKSUM="sha256:232b11680cdfe50c64a6cef1d96d3cd09a857422da1e2dd0464f80c8ddb1afac"

# TODO Update to the latest patch version
ARG JAVA_VERSION="17.0.7-oracle"

# Needed for danger-kotlin
ARG KOTLINC_VERSION="2.2.21"
ARG KOTLINC_CHECKSUM="sha256:a623871f1cd9c938946948b70ef9170879f0758043885bbd30c32f024e511714"

# === Other global args ===

ARG CMDLINE_TOOLS_DIR="cmdline-tools"
ARG CMDLINE_TOOLS_VERSION_DIR="latest"

ARG DANGER_BASE_PATH="/usr/local"
ARG KOTLINC_BASE_PATH="/usr/lib"
ARG SDKMAN_HOME="/root/.sdkman"

# === Stages ===

# == base ==

FROM dhi.io/debian-base:trixie-debian13-dev AS base

ARG CMDLINE_TOOLS_DIR
ARG CMDLINE_TOOLS_VERSION_DIR

SHELL ["/bin/bash", "-c"]

ENV ANDROID_HOME="/opt/android-sdk"

ENV PATH="$PATH:$ANDROID_HOME/$CMDLINE_TOOLS_DIR/$CMDLINE_TOOLS_VERSION_DIR"
ENV PATH="$PATH:$ANDROID_HOME/$CMDLINE_TOOLS_DIR/$CMDLINE_TOOLS_VERSION_DIR/bin"
ENV PATH="$PATH:$ANDROID_HOME/platform-tools"

# == build ==

FROM base AS build

RUN apt update && apt install -y --no-install-recommends \
    curl \
    # Needed for danger-js installation
    npm \
    unzip \
    # Needed for SDKMAN Java installation
    zip

# == java-installation ==

FROM build AS java-installation
ARG SDKMAN_HOME
ARG JAVA_VERSION

RUN curl -s "https://get.sdkman.io" | bash
RUN source "$SDKMAN_HOME/bin/sdkman-init.sh" && \
    sdk install java $JAVA_VERSION && \
    sdk use java $JAVA_VERSION

ENV JAVA_HOME="$SDKMAN_HOME/candidates/java/current"

# == android-sdk-installation ==

FROM java-installation AS android-sdk-installation
ARG ANDROID_BUILD_TOOLS_VERSION
ARG ANDROID_CMDLINE_TOOLS_VERSION
ARG ANDROID_PLATFORM_VERSION
ARG CMDLINE_TOOLS_DIR
ARG CMDLINE_TOOLS_VERSION_DIR

WORKDIR /opt

# TODO Probably keep both cmdline-tools and platform-tools in the final image, since they are not big
#  and might be useful. However, consider removing sdkmanager to prevent auto-fetching of new platforms/build tools
#  on CI once someone updates project. This will force us to keep it up-to-date in the image and avoids
#  overhead in pipelines.
ARG CMDLINE_TOOLS_ZIP="cmdline-tools.zip"
ARG CMDLINE_TOOLS_PATH="$ANDROID_HOME/$CMDLINE_TOOLS_DIR"
# Download Android SDK command line tools into $ANDROID_HOME
ADD "https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_CMDLINE_TOOLS_VERSION}_latest.zip" \
    "./$CMDLINE_TOOLS_ZIP"
RUN mkdir -p "$CMDLINE_TOOLS_PATH" && \
    unzip -q "$CMDLINE_TOOLS_ZIP" -d "$CMDLINE_TOOLS_PATH" && \
    mv "$CMDLINE_TOOLS_PATH/$CMDLINE_TOOLS_DIR" "$CMDLINE_TOOLS_PATH/$CMDLINE_TOOLS_VERSION_DIR"
# Accept licenses before installing components
# License is valid for all the standard components in versions installed from this file
# Non-standard components: MIPS system images, preview versions, GDK (Google Glass) and Android Google TV require separate licenses, not accepted there
RUN yes | sdkmanager --licenses
# platform-tools are not provided with pinned version by sdkmanager but always just the latest version
RUN sdkmanager "platform-tools"
# TODO Verify if AGP auto-fetches requires build tools and platform for build and if yes, probably remove them from image,
#  let runner job fetch it as needed by particular project and cache it using volume the same as Gradle and deps
RUN sdkmanager "build-tools;${ANDROID_BUILD_TOOLS_VERSION}"
RUN sdkmanager "platforms;android-${ANDROID_PLATFORM_VERSION}"

# == danger-installation ==

FROM build AS danger-installation
ARG DANGER_BASE_PATH
ARG DANGER_JS_VERSION
ARG DANGER_KOTLIN_VERSION
ARG DANGER_KOTLIN_CHECKSUM
ARG KOTLINC_BASE_PATH
ARG KOTLINC_CHECKSUM
ARG KOTLINC_VERSION

RUN npm install -g "danger@$DANGER_JS_VERSION"
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

FROM base AS final
ARG CMDLINE_TOOLS_DIR
ARG DANGER_BASE_PATH
ARG JAVA_VERSION
ARG KOTLINC_BASE_PATH
ARG SDKMAN_HOME

LABEL tag="ackee-gitlab" \
      author="Ackee 🦄" \
      description="This Docker image serves as an environment for running Android builds on Gitlab CI in Ackee workspace"
# Install required packages in final image
RUN apt update && apt install -y --no-install-recommends \
    git \
    # Needed for danger-js
    nodejs \
    && rm -rf /var/lib/apt/lists/*
# Set up Java
ARG JAVA_HOME="/usr/lib/jdk/$JAVA_VERSION"
COPY --from=java-installation "$SDKMAN_HOME/candidates/java/$JAVA_VERSION" "$JAVA_HOME"
ENV JAVA_HOME="$JAVA_HOME"
ENV PATH="$PATH:$JAVA_HOME/bin"
# Set up Android SDK
ARG CMDLINE_TOOLS_PATH="$ANDROID_HOME/$CMDLINE_TOOLS_DIR"
COPY --from=android-sdk-installation "$CMDLINE_TOOLS_PATH" "$CMDLINE_TOOLS_PATH"
# Set up danger-kotlin
ARG DANGER_BIN_PATH="$DANGER_BASE_PATH/bin"
COPY --from=danger-installation "$DANGER_BIN_PATH" "$DANGER_BIN_PATH"

ARG DANGER_LIB_PATH="$DANGER_BASE_PATH/lib"

ARG DANGER_NODE_MODULES_PATH="$DANGER_LIB_PATH/node_modules"
COPY --from=danger-installation "$DANGER_NODE_MODULES_PATH" "$DANGER_NODE_MODULES_PATH"

ARG DANGER_KOTLIN_LIB_PATH="$DANGER_LIB_PATH/danger"
COPY --from=danger-installation "$DANGER_KOTLIN_LIB_PATH" "$DANGER_KOTLIN_LIB_PATH"

COPY --from=danger-installation "$KOTLINC_BASE_PATH" "$KOTLINC_BASE_PATH"
ENV PATH="$PATH:$KOTLINC_BASE_PATH/kotlinc/bin"

# Set up git LFS
ARG GIT_LFS_PATH="/usr/bin/git-lfs"
COPY --from=git-lfs-installation "$GIT_LFS_PATH" "$GIT_LFS_PATH"
RUN git lfs install

RUN rm -f /usr/bin/apt /usr/bin/apt-get /usr/bin/apt-cache
RUN rm -f /bin/su
USER nonroot

# TODO This looks like a useles anonymous volume. It is not really safe to use anonymous volume,
# since it is then important to have control over container deletion and delete it in a way which
# does not delete anonymous volumes automatically ("docker run --rm" and "docker rm -v" both delete
# anonymous volumes). Also, there is this weird Gradle cache logic in ci components which seems to
# use /gradle path as a Gradle storage, so /root/.gradle seems totally irrelevant. I need to figure
# out how volumes are used on our machines and ideal solution would be to remove this anonymous volume,
# remove that caching logic from CI and just use named volume for Gradle cache like
# "docker run -v gradle-cache:/root/.gradle"
# Test this in local self-hosted gitlab + runner and figure out the best setup for caching .gradle folder

# TODO Gradle daemon is disabled by default on CI jobs in __gradle.yml base components but it is
# overridable by custom gradle-options. I think we should force it every time.
#VOLUME /root/.gradle
