ARG DISTRO="alpine"
ARG DISTRO_VARIANT="3.20"

FROM docker.io/tiredofit/${DISTRO}:${DISTRO_VARIANT}
LABEL maintainer="Dave Conroy (github.com/tiredofit)"

ARG OPENWRT_VERSION
ARG OPENWRT_CHIPSET

ENV OPENWRT_VERSION=${OPENWRT_VERSION:-"23.05.4"} \
    OPENWRT_CHIPSET=${OPENWRT_CHIPSET:-"ipq40xx"} \
    CONTAINER_ENABLE_MESSAGING=FALSE \
    CONTAINER_PROCESS_RUNAWAY_PROTECTOR=FALSE \
    IMAGE_NAME="tiredofit/openwrt-builder" \
    IMAGE_REPO_URL="https://github.com/tiredofit/docker-openwrt-builder/"

RUN source /assets/functions/00-container && \
    set -x && \
    package install .openwrt-run-deps \
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
                    && \
    \
    if [ "${OPENWRT_VERSION}" = "snapshot" ]; then _url_prefix="/snapshots/targets/" ; else _url_prefix="/releases/${OPENWRT_VERSION}/targets/" ; fi ; \
    \
    for chipset in $(echo ${OPENWRT_CHIPSET} | sed -e "s|, |,|g" -e "s| |,|g" | tr "," "\n") ; do \
        mkdir -p /src/${chipset}/ && \
        if [ ${OPENWRT_VERSION} != "snapshot" ] ; then \
            curl -sSL https://downloads.openwrt.org/"${_url_prefix}"${chipset}/generic/openwrt-imagebuilder-${OPENWRT_VERSION}-${chipset}-generic.Linux-x86_64.tar.xz | tar xfaJ - --strip 1 -C /src/${chipset}/ ; \
        else \
            curl -sSL https://downloads.openwrt.org/"${_url_prefix}"${chipset}/generic/openwrt-imagebuilder-${chipset}-generic.Linux-x86_64.tar.zst | tar xfa - --zstd --strip 1 -C /src/${chipset}/ ; \
        fi ; \
    done ;

ADD install/ /
