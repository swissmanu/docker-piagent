FROM node:24-bookworm-slim

ARG PI_VERSION=1.3.0
ARG PASEO_VERSION=0.15.3
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash ca-certificates curl dnsutils git iproute2 procps ripgrep \
    && rm -rf /var/lib/apt/lists/* \
    && npm install --global --ignore-scripts \
        "@earendil-works/pi-coding-agent@${PI_VERSION}" \
        "@getpaseo/cli@${PASEO_VERSION}" \
    && npm cache clean --force

# The official Node image supplies UID/GID 1000. Writable paths are supplied
# by emptyDir volumes, not by permissions on the image's root filesystem.
ENV HOME=/home/node \
    PASEO_HOME=/home/node/.paseo \
    PASEO_LISTEN=0.0.0.0:6767 \
    PASEO_RELAY_ENABLED=false

USER node
WORKDIR /workspace
EXPOSE 6767
ENTRYPOINT ["paseo", "daemon", "run"]
