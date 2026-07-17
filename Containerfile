# SPDX-FileCopyrightText: © 2026 Nfrastack <code@nfrastack.com>
#
# SPDX-License-Identifier: MIT

ARG BASE_IMAGE

FROM ${BASE_IMAGE}

LABEL \
        org.opencontainers.image.title="OpenWRT Builder" \
        org.opencontainers.image.description="OpenWRT Image Builder Container" \
        org.opencontainers.image.url="https://hub.docker.com/r/nfrastack/openwrt-builder" \
        org.opencontainers.image.documentation="https://github.com/nfrastack/container-openwrt-builder/blob/main/README.md" \
        org.opencontainers.image.source="https://github.com/nfrastack/container-openwrt-builder.git" \
        org.opencontainers.image.authors="Nfrastack <code@nfrastack.com>" \
        org.opencontainers.image.vendor="Nfrastack <https://www.nfrastack.com>" \
        org.opencontainers.image.licenses="MIT"

ARG \
    OPENWRT_VERSION="25.12.5" \
    OPENWRT_CHIPSET="ipq40xx:generic,mediatek/filogic" \
    OPENWRT_REPO_URL="https://downloads.openwrt.org"

COPY CHANGELOG.md /usr/src/container/CHANGELOG.md
COPY LICENSE /usr/src/container/LICENSE
COPY README.md /usr/src/container/README.md

COPY build-assets/ /build-assets

ENV \
    IMAGE_NAME="nfrastack/openwrt-builder" \
    IMAGE_REPO_URL="https://github.com/nfrastack/container-openwrt-builder/"

RUN echo "" && \
    BUILD_ENV=" \
                CONTAINER_PROCESS_RUNAWAY_PROTECTOR=FALSE \
              " \
              && \
    OPENWRT_BUILD_DEPS_ALPINE=" \
                                bzip2 \
                                coreutils \
                                diffutils \
                                file \
                                findutils \
                                gawk \
                                git \
                                gzip \
                                make \
                                patch \
                                perl \
                                perl-data-dump \
                                perl-file-copy-recursive \
                                py3-setuptools \
                                tar \
                                unzip \
                                wget \
                                xz \
                                zstd \
                            " \
                            && \
    \
    source /container/base/functions/container/build && \
    container_build_log image && \
    create_user openwrt 1000 openwrt 1000 /dev/null && \
    package update && \
    package upgrade && \
    package install \
                    OPENWRT_BUILD_DEPS \
                    && \
    \
    if [ "${OPENWRT_VERSION}" = "snapshot" ]; then _url_prefix="/snapshots/targets/" ; else _url_prefix="/releases/${OPENWRT_VERSION}/targets/" ; fi ; \
    \
    for entry in $(echo ${OPENWRT_CHIPSET} | sed -e "s|, |,|g" -e "s| |,|g" | tr "," "\n") ; do \
        chipset="${entry%:*}" ; \
        subtarget="${entry#*:}" ; \
        if [ "${subtarget}" = "${chipset}" ] || [ -z "${subtarget}" ] ; then \
            _sub_url="" ; \
            _sub_file="" ; \
        else \
            _sub_url="${subtarget}/" ; \
            _sub_file="-${subtarget}" ; \
        fi ; \
        _chipset_file="${chipset//\//-}" ; \
        mkdir -p /src/${chipset}/ && \
        ext="zst" ; \
        case "${OPENWRT_VERSION:0:2}" in \
          23 ) \
             ext="xz" ; \
             _decompress="xz -d" ; \
          ;; \
          * ) \
             _decompress="zstd -d" ; \
          ;; \
        esac && \
        if [ "${OPENWRT_VERSION}" != "snapshot" ] ; then \
            _url="https://downloads.openwrt.org${_url_prefix}${chipset}/${_sub_url}openwrt-imagebuilder-${OPENWRT_VERSION}-${_chipset_file}${_sub_file}.Linux-x86_64.tar.${ext}" ; \
        else \
            _url="https://downloads.openwrt.org${_url_prefix}${chipset}/${_sub_url}openwrt-imagebuilder-${_chipset_file}${_sub_file}.Linux-x86_64.tar.${ext}" ; \
        fi && \
        { \
            _http_code=$(curl -fsSL -w "%{http_code}" -o "/tmp/sdk-${chipset//\//_}.tar.${ext}" --connect-timeout 60 --max-time 600 "${_url}" 2>&1) && \
            echo "HTTP ${_http_code}" && \
            case "${ext}" in \
                xz ) xz -d -c "/tmp/sdk-${chipset//\//_}.tar.${ext}" ;; \
                zst ) zstd -d -c "/tmp/sdk-${chipset//\//_}.tar.${ext}" ;; \
            esac | tar -x -f - --strip 1 -C /src/${chipset}/ && \
            rm -f "/tmp/sdk-${chipset//\//_}.tar.${ext}" ; \
        } || { \
            echo "ERROR: Failed to download SDK for ${chipset}"; \
            echo "URL: ${_url}"; \
            rm -f "/tmp/sdk-${chipset//\//_}.tar.${ext}"; \
            exit 1; \
        } ; \
    done && \
    \
    container_build_log add "OpenWRT Builder" "${OPENWRT_VERSION}" "${OPENWRT_REPO_URL}" && \
    package cleanup

COPY rootfs /
