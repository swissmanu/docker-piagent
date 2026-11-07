#!/usr/bin/env bash
set -euo pipefail

# Build first: docker build -t piagent:test .
image=${1:-piagent:test}
name="piagent-smoke-$$"
trap 'docker rm -f "$name" >/dev/null 2>&1 || true' EXIT

docker run -d --name "$name" \
  --read-only --cap-drop=ALL --security-opt=no-new-privileges \
  --tmpfs /home/node:uid=1000,gid=1000,mode=0700,exec \
  --tmpfs /tmp:mode=1777 \
  --tmpfs /workspace:uid=1000,gid=1000 \
  -e PASEO_PASSWORD=smoke-test-only "$image" >/dev/null

ready=false
for ((attempt = 0; attempt < 60; attempt++)); do
  if docker exec "$name" curl -fsS http://127.0.0.1:6767/api/health >/dev/null 2>&1 &&
    docker exec "$name" paseo ls --host 127.0.0.1:6767 >/dev/null 2>&1; then
    ready=true
    break
  fi
  sleep 1
done
if [[ "$ready" != true ]]; then
  docker logs "$name"
  exit 1
fi

[[ $(docker exec "$name" id -u) == 1000 ]]
docker exec "$name" paseo provider diagnostic pi --host 127.0.0.1:6767 --json
# An explicit TCP target exercises password auth rather than the local IPC path.
if docker exec -e PASEO_PASSWORD=wrong "$name" paseo ls --host 127.0.0.1:6767 >/dev/null 2>&1; then
  echo 'Daemon accepted an incorrect password' >&2
  exit 1
fi
logs=$(docker logs "$name" 2>&1)
if ! grep -q 'Launched terminal worker' <<<"$logs" || grep -q 'Terminal worker did not start' <<<"$logs"; then
  printf '%s\n' "$logs"
  exit 1
fi

docker stop -t 15 "$name" >/dev/null
[[ $(docker inspect -f '{{.State.ExitCode}}' "$name") != 137 ]]
echo 'Paseo smoke test passed'
