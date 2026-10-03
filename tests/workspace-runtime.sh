#!/usr/bin/env bash
# Run inside the image with the normal entrypoint bypassed.
set -euo pipefail
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/repo" "$fixture/home/.ssh" "$fixture/tools"
export APP_ROOT="$fixture/repo" HOME="$fixture/home"
printf 'Host saved\n' > "$HOME/.ssh/config"
printf '[user]\n  name = Developer\n' > "$HOME/.gitconfig"
cp "$HOME/.ssh/config" "$fixture/ssh.expected"
cp "$HOME/.gitconfig" "$fixture/git.expected"
# Configuration succeeds repeatedly without running storage/init or identity setup.
/docker-entrypoint.sh --configure-runtime
/docker-entrypoint.sh --configure-runtime
cmp "$HOME/.ssh/config" "$fixture/ssh.expected"
cmp "$HOME/.gitconfig" "$fixture/git.expected"
bash -lc 'command -v go' >/dev/null
cd "$APP_ROOT"
git init -q
printf 'tracked\n' > source.txt
git add source.txt
workspace-path > "$fixture/path"
test "$(cat "$fixture/path")" = "$APP_ROOT/.wodby-workspace"
test -z "$(git ls-files --others --exclude-standard)"
# A tracked collision is refused, even when local exclude rules hide new files.
printf collision > .wodby-workspace/collision
git add -f .wodby-workspace/collision
if workspace-path; then echo 'accepted tracked runtime storage' >&2; exit 1; fi
git rm -q --cached .wodby-workspace/collision
rm .wodby-workspace/collision
export PATH="$fixture/tools:$PATH"
# A real build proves application metadata is unchanged and startup recompiles.
printf 'module example.test/workspace\n\ngo 1.22\n' > go.mod
printf 'package main\nimport "fmt"\nfunc main(){fmt.Print("before")}\n' > main.go
cp go.mod "$fixture/mod.expected"
workspace-go prepare
test "$(workspace-go start)" = before
# Compiled packages are kept with the checkout, not in the container's home,
# which a restart discards; a custom start command gets the same caches.
state="$APP_ROOT/.wodby-workspace"
test -n "$(ls -A "$state/cache")"
test "$(WORKSPACE_GO_COMMAND='go env GOMODCACHE GOCACHE GOFLAGS' workspace-go start)" = "$state/mod
$state/cache
-modcacherw"
test -z "$(git ls-files --others --exclude-standard -- .wodby-workspace)"
# Caches set to anything else stay as set.
test "$(GOMODCACHE="$fixture/mod" GOCACHE="$fixture/cache" WORKSPACE_GO_COMMAND='go env GOMODCACHE GOCACHE GOFLAGS' workspace-go start)" = "$fixture/mod
$fixture/cache"
sed -i 's/before/after/' main.go
test "$(WODBY_WORKSPACE=1 /docker-entrypoint.sh ignored)" = after
cmp go.mod "$fixture/mod.expected"
test ! -f go.sum
cmp "$HOME/.ssh/config" "$fixture/ssh.expected"
cmp "$HOME/.gitconfig" "$fixture/git.expected"
echo 'Workspace runtime checks passed'
