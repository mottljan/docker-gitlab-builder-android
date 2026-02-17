# Docker image for Android builds on GitLab CI

Docker image providing a complete environment for running Android builds on GitLab CI in Ackee workspace.

## Contents

- Java 17 (OpenJDK from Eclipse Temurin)
- Android SDK (cmdline-tools, platform tools, build-tools)
- danger-kotlin + danger-js + Kotlin compiler
- Node.js (system package, required by danger-js)
- Git LFS
- Base: dhi.io/debian-base

## Security

- Runs as unprivileged `nonroot` user
- Privilege escalation binaries removed (`su`, `apt`, `dpkg`, `unix_chkpwd`)
- npm scripts disabled to guard against supply chain attacks
- [shai-hulud](https://github.com/AckeeCZ/shai-hulud) supply chain attack detector runs at build time
- All downloaded artifacts verified with checksums

## Local development

### Prerequisites

Two logins are required. A dedicated personal access token for local testing can be found in 
Passwd under **"docker-gitlab-builder-android local test"**.

```shell
docker login dhi.io      # Required to pull the hardened base image
docker login docker.io   # Required for Docker Scout CVE analysis
```

### Build

```shell
docker compose build
```

Optionally run shai-hulud in paranoid mode:

```shell
docker compose build --build-arg SHAI_HULUD_DETECTOR_MODE=--paranoid
```

### Test

```shell
docker compose run --rm gitlab-builder-android
```

This runs `image-test.sh` inside the container, which checks security properties, verifies all 
required tools are present and functional, and runs a real Gradle build against the bundled `image-test-app`.

## CI

### Image lint (dockle)

Dockle is used via `erzz/dockle-action` in the common-preflight-check GitHub Actions composite action. 
It runs automatically on every PR and deploy, after the build and test steps.

To reproduce locally (requires dockle installed):

```shell
dockle --exit-code 1 ackee/gitlab-builder-android:test
```

### Docker Scout

On pull requests, Docker Scout scans the built image for critical/high CVEs that have a fix available 
and posts results as a PR comment for manual review. Does not ever fail the pipeline, because usually
it is not easily possible to fix even fixable CVEs, because they can come from transitive dependencies.
