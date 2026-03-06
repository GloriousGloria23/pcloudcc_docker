# -*-Dockerfile-*-

ARG DEBIAN_VERSION=bookworm

FROM debian:${DEBIAN_VERSION} AS builder

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       cmake \
       zlib1g-dev \
       libboost-system-dev \
       libboost-program-options-dev \
       libpthread-stubs0-dev \
       libfuse-dev \
       libudev-dev \
       libsqlite3-dev \
       fuse \
       build-essential \
       git \
       make \
       ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /usr/src

# Pin the repo to the latest tested commit.
ARG console_client_sha=980d2cadf670f1b14642c7dbe015f95bd2306175

RUN cd /usr/src \
    && git clone https://github.com/pcloudcom/console-client \
    && cd console-client \
    && git reset --hard ${console_client_sha} \
    && git config user.email "docker@builder.com" \
    && git config user.name "Docker Builder" \
    && git fetch origin pull/163/head:mfa_branch \
    && git merge mfa_branch --no-edit

WORKDIR /usr/src/console-client
# Remove -mtune arg
# https://github.com/pcloudcom/console-client/issues/175
ARG TARGETPLATFORM
RUN if [ "${TARGETPLATFORM}" != "linux/amd64" ] ; then \
        sed "s/-mtune=core2//g" -i ./pCloudCC/lib/pclsync/Makefile ; \
    fi

# Patch mbedtls to work on arm/v7
# https://github.com/pcloudcom/console-client/issues/49
# https://github.com/Mbed-TLS/mbedtls-docs/blob/main/kb/development/arm-thumb-error-r7-cannot-be-used-in-asm-here.md
RUN if [ "${TARGETPLATFORM}" = "linux/arm/v7" ] ; then \
        sed "s/-Wall/-Wall -fomit-frame-pointer/g" -i ./pCloudCC/lib/mbedtls/CMakeLists.txt ; \
    fi

RUN cd pCloudCC \
    && cmake -D CMAKE_BUILD_TYPE=Release -D CMAKE_INSTALL_PREFIX=/usr . \
    && make pclsync mbedtls install/strip

FROM debian:${DEBIAN_VERSION}-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       fuse \
       lsb-release \
       gosu \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /usr/bin/pcloudcc /usr/bin/pcloudcc
COPY --from=builder /usr/lib/libpcloudcc_lib.so /usr/lib/libpcloudcc_lib.so

COPY entrypoint.sh /
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]