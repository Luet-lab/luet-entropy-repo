FROM quay.io/luet/base:develop
ADD conf/luet-dso.yaml /etc/luet/.luet.yaml

ENV USER=root

SHELL ["/usr/bin/luet", "install", "-d"]

# meta/users initialize /bin/sh as a link to /bin/bash
RUN meta/users-0

SHELL ["/bin/bash", "-c"]
RUN rm -rf /var/cache/luet/packages/ /var/cache/luet/repos/

ENV TMPDIR=/tmp
ENTRYPOINT ["/bin/bash"]
