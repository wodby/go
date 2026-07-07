#!/usr/bin/env bash

set -e

if [[ -n "${DEBUG}" ]]; then
    set -x
fi

go version | grep -q "go${GO_VERSION}"

ssh sshd cat /home/wodby/.ssh/authorized_keys | grep -q admin@example.com

curl -s nginx | grep -q "Go test app"
curl -s localhost:8080 | grep -q "Go test app"
