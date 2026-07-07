# Go Docker Container Images

[![Build Status](https://github.com/wodby/go/workflows/Build%20docker%20image/badge.svg)](https://github.com/wodby/go/actions)
[![Docker Pulls](https://img.shields.io/docker/pulls/wodby/go.svg)](https://hub.docker.com/r/wodby/go)
[![Docker Stars](https://img.shields.io/docker/stars/wodby/go.svg)](https://hub.docker.com/r/wodby/go)

## Table of Contents

- [Docker Images](#docker-images)
    - [`-dev`](#-dev)
    - [`-dev-macos`](#-dev-macos)
    - [Supported architectures](#supported-architectures)
- [Environment Variables](#environment-variables)
- [Build arguments](#build-arguments)
- [Tools](#tools)
- [Changelog](#changelog)
- [Crond](#crond)
- [SSHD](#sshd)
- [Adding SSH key](#adding-ssh-key)
- [Complete Go stack](#complete-go-stack)
- [Orchestration Actions](#orchestration-actions)

## Docker Images

For better reliability we release images with stability tags (`wodby/go:1.26-X.X.X`) which correspond to [git tags](https://github.com/wodby/go/releases). We strongly recommend using images only with stability tags.

About images:

- All images are based on Alpine Linux
- Base image: [golang](https://github.com/docker-library/golang)
- [GitHub actions builds](https://github.com/wodby/go/actions)
- [Docker Hub](https://hub.docker.com/r/wodby/go)

Supported tags and respective `Dockerfile` links:

- `1.26`, `1`, `latest` [_(Dockerfile)_]
- `1.25` [_(Dockerfile)_]
- `1.26-dev`, `1-dev`, `dev` [_(Dockerfile)_]
- `1.25-dev` [_(Dockerfile)_]
- `1.26-dev-macos`, `1-dev-macos` [_(Dockerfile)_]
- `1.25-dev-macos` [_(Dockerfile)_]

[_(Dockerfile)_]: https://github.com/wodby/go/tree/master/Dockerfile

### `-dev`

Images with `-dev` tag have `sudo` allowed for all commands for the `wodby` user and include build dependencies for cgo-based projects.

### `-dev-macos`

Same as `-dev` but the default user/group `wodby` has uid/gid `501`/`20` to match the macOS default user/group ids.

### Supported architectures

All images are built for `linux/amd64`, `-dev-macos` images are additionally built for `linux/arm64`.

## Environment Variables

| Variable                          | Default value                 |
|-----------------------------------|-------------------------------|
| `APP_ROOT`                        | `/usr/src/app`                |
| `FILES_DIR`                       | `/mnt/files`                  |
| `GIT_USER_EMAIL`                  | `wodby@example.com`           |
| `GIT_USER_NAME`                   | `wodby`                       |
| `GOCACHE`                         | `/home/wodby/.cache/go-build` |
| `GOMODCACHE`                      | `/home/wodby/go/pkg/mod`      |
| `GOPATH`                          | `/home/wodby/go`              |
| `SSH_DISABLE_STRICT_KEY_CHECKING` |                               |
| `SSH_PRIVATE_KEY`                 |                               |
| `SSHD_GATEWAY_PORTS`              | `no`                          |
| `SSHD_HOST_KEYS_DIR`              | `/etc/ssh`                    |
| `SSHD_LOG_LEVEL`                  | `INFO`                        |
| `SSHD_PASSWORD_AUTHENTICATION`    | `no`                          |
| `SSHD_PERMIT_USER_ENV`            | `no`                          |
| `SSHD_USE_DNS`                    | `yes`                         |

## Build arguments

| Argument         | Default value |
|------------------|---------------|
| `GO_DEV`         |               |
| `WODBY_GROUP_ID` | `1000`        |
| `WODBY_USER_ID`  | `1000`        |

Change `WODBY_USER_ID` and `WODBY_GROUP_ID` mainly for local dev image variants. If either value matches an existing system user/group id, the existing user/group will be deleted before creating the `wodby` user.

## Tools

| Tool        | all versions |
|-------------|--------------|
| Go toolchain | bundled from the upstream `golang` image |
| make        | latest Alpine package |
| git         | latest Alpine package |

## Changelog

Changes per stability tag are reflected in git tag descriptions under [releases](https://github.com/wodby/go/releases).

## Crond

You can run Crond with this image by changing the command to `sudo -E crond -f -d 0` and mounting a crontab file to `./crontab:/etc/crontabs/wodby`. Example crontab file contents:

```
# min	hour	day	month	weekday	command
*/1	*	*	*	*	echo "test" > /mnt/files/cron
```

## SSHD

You can run SSHD with this image by changing the command to `sudo /usr/sbin/sshd -De` and mounting authorized public keys to `/home/wodby/.ssh/authorized_keys`.

## Adding SSH key

You can add a private SSH key to the container by mounting it to `/home/wodby/.ssh/id_rsa`.

## Complete Go stack

See https://github.com/wodby/stack-go

## Orchestration Actions

Usage:

```
make COMMAND [params ...]

commands:
    check-ready [host max_try wait_seconds delay_seconds]
    files-import source
    files-link public_dir
```
