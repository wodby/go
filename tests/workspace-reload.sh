#!/usr/bin/env bash
# A change another container writes to the shared checkout is compiled and served without
# restarting the container, a build that fails leaves the running build up, and the watcher
# stops with its application. This does not substitute for cross-node NFS acceptance.
set -euo pipefail
volume="workspace-go-reload-$$"
server="workspace-go-reload-server-$$"
docker volume create "$volume" >/dev/null
cleanup() { docker rm -f "$server" >/dev/null 2>&1 || true; docker volume rm "$volume" >/dev/null; }
trap cleanup EXIT
image="${IMAGE:?Set IMAGE to the candidate Go development image}"
# Run as the image's own user: the checkout belongs to it in a workspace.
write() { docker run --rm -i --network none --entrypoint sh -v "$volume:/fixture" "$image" -ec "$1"; }
docker run --rm --user 0 --entrypoint sh -v "$volume:/fixture" "$image" -ec 'chown "$(id -u wodby):$(id -g wodby)" /fixture'
write '
cd /fixture
git init -q
printf "module example.test/reload\n\ngo 1.22\n" > go.mod
printf "embedded-before" > static.txt
cat > main.go <<GO
package main

import (
	_ "embed"
	"net/http"
	"os"
)

//go:embed static.txt
var static string

func main() {
	http.HandleFunc("/", func(w http.ResponseWriter, _ *http.Request) { w.Write([]byte("before-edit")) })
	http.HandleFunc("/static", func(w http.ResponseWriter, _ *http.Request) { w.Write([]byte(static)) })
	http.HandleFunc("/exit", func(http.ResponseWriter, *http.Request) { os.Exit(7) })
	http.ListenAndServe(":" + os.Getenv("PORT"), nil)
}
GO
'
start() { docker run -d --name "$server" --network none --entrypoint /usr/local/bin/workspace-go -e APP_ROOT=/fixture -e WORKSPACE_POLL_INTERVAL=500 "$@" -v "$volume:/fixture" "$image" start >/dev/null; }
get() { docker exec "$server" wget -qO- "http://127.0.0.1:8080$1" 2>/dev/null; }
# Waits until a path answers with the wanted text; prints the server's log when it never does.
serves() {
 for _ in $(seq 1 90); do
  if [ "$(get "$1" || true)" = "$2" ]; then return 0; fi
  sleep 1
 done
 echo "$1 never answered $2" >&2; docker logs "$server" >&2; exit 1
}
start
serves / before-edit
serves /static embedded-before
first=$(docker inspect -f '{{.State.StartedAt}}' "$server")

write 'sed -i "s/before-edit/after-edit/" /fixture/main.go'
serves / after-edit
echo 'go: a change to the source was compiled and served'

# A build that fails must not take the running build down.
write 'printf "\nfunc broken( {\n" >> /fixture/main.go'
for _ in $(seq 1 60); do
 if docker logs "$server" 2>&1 | grep -q 'the build failed; the previous build keeps running'; then break; fi
 sleep 1
done
docker logs "$server" 2>&1 | grep -q 'the build failed; the previous build keeps running'
serves / after-edit
echo 'go: a failed build left the running build up'

# Fixed again, with a change to a file the build embeds.
write 'sed -i "/^func broken( {$/d" /fixture/main.go; printf "embedded-after" > /fixture/static.txt'
serves /static embedded-after
echo 'go: a change to an embedded file was compiled and served'

# All of that happened in one container.
test "$(docker inspect -f '{{.State.StartedAt}} {{.RestartCount}}' "$server")" = "$first 0"

# Storage for builds and caches is not watched: nothing is compiled while nothing changes.
builds=$(docker logs "$server" 2>&1 | grep -c 'the checkout changed; compiling')
sleep 5
test "$(docker logs "$server" 2>&1 | grep -c 'the checkout changed; compiling')" = "$builds"

# Stopping the container stops the application at once, without waiting for the kill timeout.
began=$(date +%s)
docker stop -t 30 "$server" >/dev/null
test $(( $(date +%s) - began )) -lt 10
test "$(docker inspect -f '{{.State.ExitCode}}' "$server")" = 143
docker rm -f "$server" >/dev/null
echo 'go: stopping the container stopped the application'

# An application that ends by itself ends the container with its exit code.
start
serves / after-edit
get /exit || true
for _ in $(seq 1 20); do
 [ "$(docker inspect -f '{{.State.Running}}' "$server")" = false ] && break
 sleep 1
done
test "$(docker inspect -f '{{.State.Running}} {{.State.ExitCode}}' "$server")" = 'false 7'
docker rm -f "$server" >/dev/null
echo 'go: an application that ended took the container with it'

# Without watching the application replaces the script, as before.
start -e WORKSPACE_GO_WATCH=0
serves / after-edit
test "$(docker exec "$server" sh -c 'tr "\0" " " < /proc/1/cmdline')" = '/fixture/.wodby-workspace/app '
write 'sed -i "s/after-edit/unwatched/" /fixture/main.go'
sleep 5
test "$(get /)" = after-edit
echo 'go: WORKSPACE_GO_WATCH=0 runs the application without a watcher'
