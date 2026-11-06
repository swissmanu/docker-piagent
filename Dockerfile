FROM node:24-bookworm-slim

ARG PI_VERSION=1.3.0
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash ca-certificates curl dnsutils git iproute2 ripgrep \
    && rm -rf /var/lib/apt/lists/* \
    && npm install --global --ignore-scripts \
        "@earendil-works/pi-coding-agent@${PI_VERSION}" \
    && npm cache clean --force

# The official Node image supplies UID/GID 1000. Writable paths are supplied
# by emptyDir volumes, not by permissions on the image's root filesystem.
USER node
WORKDIR /workspace
ENTRYPOINT ["pi"]
