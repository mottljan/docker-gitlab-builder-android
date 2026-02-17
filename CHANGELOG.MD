# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [v3.0.0] - 2026-02-17
### Changed
- Complete rewrite of Dockerfile using multi-stage build architecture (separate stages for Java, Android SDK, Danger, Git LFS)
- Danger JS installation now runs as `nonroot` user to reduce attack surface
- Node.js installed from system apt packages instead of via nvm
- Updated Android cmdline-tools to 14742923, platform to 36, build-tools to 36.1.0

### Added
- Checksum verification for all downloaded artifacts (Java, Kotlin compiler, danger-kotlin)
- Integration of shai-hulud supply chain attack detector for npm packages
- npm scripts disabled globally to prevent supply chain attacks
- Final image runs as `nonroot` user

### Removed
- Flutter support
- nvm and Node.js version management
- Google Cloud CLI
- Privilege escalation binaries from final image (`su`, `apt`, `apt-get`, `apt-cache`, `dpkg`, `unix_chkpwd`)

## [v2.8.0] - 2025-12-04
### Changed
- Update danger kotlin to 1.3.4
- Update kotlin compiler for danger kotlin to 2.2.21
- Update danger js to 12.3.4
- Update debian version to `trixie`
- Added repository and key for Google cloud CLI package
- Fixed other non-working apt dependencies
- Minor refactor of environment variables

### Removed
- Remove env variable previously added for Dependency-Check plugin

## [v2.7.0] - 2025-07-08
### Changed
- Update node to 23.5.0

## [v2.6.0] - 2024-11-05
### Changed
- Update danger kotlin to 1.3.1
- Update kotlin compiler for danger kotlin to 2.0.21

## [v2.5.0] - 2024-09-13
### Changed
- Update flutter version to 3.24.3

## [v2.4.1] - 2024-08-28
### Add
- Add CI helper functions

## [v2.3.0] - 2024-05-03
### Add
- Support for git LFS

## [v2.2.0] - 2024-03-11
### Upgraded
- Node, nvm and Danger

## [v2.1.0] - 2024-02-23
### Add
- env variable to make Dependency-Check plugin work

## [v2.0.0] - 2023-05-22
### Changed
- Debian `stretch` to `buster` due to apt mirror missing packages
- Updated danger to work with current gradle
- Updated kotlin
### Add
- Exception for root build of `/opt/flutter` to avoid `flutter doctor` error

## [v1.4.0] - 2023-05-22
### Changed
- Update to Java 17

## [v1.3.2] - 2023-04-04
### Changed
- Update flutter version to 3.7.9

## [v1.3.1] - 2022-06-09
### Changed
- Update flutter version to 3.0.1

## [v1.3.0] - 2022-05-05
### Changed
- Update flutter version to 2.10.0
- Change flutter archive url

## [v1.2.0] - 2021-07-12
### Added
- Add flutter dependencies

## [v1.1.0] - 2021-07-12
### Added
- Add labels

## [v1.0.2] - 2021-04-14
### Added
- Add java bin folder to the PATH

## [v1.0.1] - 2021-04-09
### Added
- Install fontconfig dependency because of easylauncher plugin

## [v1.0.0] - 2021-04-07 
### Changed 
- Replace Java 8 with Java 11 due to new Android Gradle Plugin requirements.
- Use sdkman to manage java versions
### Added
- Add README/CHANGELOG and introduce proper tagging
