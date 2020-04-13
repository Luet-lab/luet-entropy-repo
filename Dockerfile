FROM quay.io/luet/base:develop
ADD conf/luet-dso.yaml /etc/luet/.luet.yaml

ENV USER=root
# TODO: Temporary fix that require a fix in luet
# on create temporary directory used for download repositories
# data
ENV TMPDIR=/

SHELL ["/usr/bin/luet", "install", "-d"]

RUN sys-apps/coreutils
RUN >=sys-devel/base-gcc-8.2.0-0
RUN app-shells/bash

SHELL ["/bin/bash", "-c"]
RUN rm -rf /var/cache/luet/packages/ /var/cache/luet/repos/
# Temporay until TMPDIR is clean
RUN rm -rf /tree*

ENTRYPOINT ["/bin/bash"]
