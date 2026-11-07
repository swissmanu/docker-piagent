# 🐳 `ghcr.io/swissmanu/piagent`

A non-root image running a **headless Paseo daemon**, with Pi installed as an
agent provider. The default command is `paseo daemon run`; Paseo listens on
`0.0.0.0:6767` and its outbound relay is disabled. No desktop or browser is
launched. The bundled web UI is disabled unless explicitly enabled.

## Run

Provide a strong password in `PASEO_PASSWORD` (use a Secret in Kubernetes).
For a local test:

```bash
export PASEO_PASSWORD='replace-with-a-strong-password'
docker run -d --name piagent \
  --read-only --cap-drop=ALL --security-opt=no-new-privileges \
  -p 127.0.0.1:6767:6767 \
  -e PASEO_PASSWORD \
  --mount type=volume,src=piagent-home,dst=/home/node \
  --mount type=bind,src="$PWD",dst=/workspace \
  --tmpfs /tmp:mode=1777 \
  ghcr.io/swissmanu/piagent:latest
```

The image never starts as root or changes mounted-volume ownership. All writable
mounts must be accessible to **UID/GID 1000:1000**. A new Docker home volume inherits
the image's home ownership; existing volumes and bind mounts need suitable permissions.

### Writable paths

| Path | Purpose |
| --- | --- |
| `/home/node` | Paseo state (`.paseo`), Pi config/credentials/sessions (`.pi`), caches and agent runtime files. Persist this to retain sessions and credentials. |
| `/workspace` | Repositories and files agents can modify. |
| `/tmp` | Temporary files; an ephemeral volume is sufficient. |

For Kubernetes, use `runAsUser: 1000`, `runAsGroup: 1000`,
`runAsNonRoot: true`, `readOnlyRootFilesystem: true`,
`allowPrivilegeEscalation: false`, and drop all capabilities. Supply writable
volumes at the paths above; use `fsGroup: 1000` where supported to grant volume
access. `emptyDir` works, but its contents disappear when the Pod is removed.

**The home volume must permit execution and native-library loading**: Paseo
materializes its terminal worker there. Docker tmpfs mounts default to `noexec`;
for an ephemeral home use
`--tmpfs /home/node:uid=1000,gid=1000,mode=0700,exec`.

## Your network infrastructure

Route HTTP and WebSocket upgrades to port **6767**, with TLS terminated at your
ingress/reverse proxy. Set `PASEO_HOSTNAMES` to the DNS names used to reach the
daemon (for example `paseo.example.com`). IPs and `localhost` are allowed by default.
Only configure `PASEO_TRUSTED_PROXIES` for proxy ranges you actually trust.

Set `PASEO_PASSWORD` for every network-reachable deployment. Paseo clients use the
same password for a direct connection; the relay is not needed. Health probes can
use unauthenticated `GET /api/health` on port 6767.

Optional environment settings:

- `PASEO_LISTEN`: override the listen address (default `0.0.0.0:6767`).
- `PASEO_WEB_UI_ENABLED=true`: serve the bundled browser client on the same port.
- `PASEO_RELAY_ENABLED`: defaults to `false` for this image.

With a Paseo CLI installed on your client machine:

```bash
PASEO_PASSWORD='your-password' paseo --host your-host:6767 provider diagnostic pi
PASEO_PASSWORD='your-password' paseo --host your-host:6767 run --provider pi 'Review this project'
```

Use a Paseo client's direct-connection settings when connecting through your TLS
ingress. Register your repository/workspace with Paseo before starting work.

## Pi authentication and configuration

Pass the API-key environment variables required by your Pi model provider (for
example `ANTHROPIC_API_KEY`), or authenticate interactively:

```bash
docker exec -it piagent pi
```

Pi credentials and settings live under `/home/node/.pi/agent`. Paseo configuration
lives at `/home/node/.paseo/config.json`. Mount only repositories and credentials
you intend the agent to access.

Paseo can download local speech models on first startup. For text-only operation,
set `features.dictation.enabled` and `features.voiceMode.enabled` to `false` in
its `config.json` before starting the daemon.

To run Pi directly instead of Paseo:

```bash
docker run --rm -it --entrypoint pi ghcr.io/swissmanu/piagent:latest
```

## Build and smoke test

Versions are pinned by `PI_VERSION` and `PASEO_VERSION` build arguments.

```bash
docker build -t piagent:test .
bash tests/smoke.sh piagent:test
```

The smoke test checks daemon health, Pi discovery, TCP password authentication,
terminal-worker startup, and shutdown with a read-only root filesystem and UID 1000.
It does not make a paid model request.

Upstream reference: [Paseo configuration](https://paseo.sh/docs/configuration).
