# SPDX-License-Identifier: GPL-2.0-only
FROM --platform=linux/amd64 ubuntu:20.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash bc bison build-essential ca-certificates curl flex git kmod \
    libelf-dev libssl-dev libncurses5 libtinfo5 python2 python3 xz-utils \
    && rm -rf /var/lib/apt/lists/*
ENTRYPOINT ["bash", "/kit/build.sh"]
