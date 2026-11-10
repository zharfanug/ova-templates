# Builder image: everything needed to build a disk image and package it
# as an OVA. Runs privileged (loop devices, mount, chroot); see run.sh.
FROM debian:trixie-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        btrfs-progs \
        ca-certificates \
        curl \
        debian-archive-keyring \
        debootstrap \
        dmsetup \
        dosfstools \
        kpartx \
        libxml2-utils \
        parted \
        python3 \
        qemu-utils \
        rsync \
        util-linux \
    && rm -rf /var/lib/apt/lists/*

ENV LC_ALL=C.UTF-8

WORKDIR /work

CMD ["/bin/bash"]
