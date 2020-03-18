#!/bin/bash

LUET_ENTROPY_REPO=${LUET_ENTROPY_REPO:-https://github.com/Luet-lab/luet-entropy-repo.git}
LUET_EXCLUDES="${LUET_EXCLUDES:---exclude acct-group --exclude acct-user --exclude}"
LUET_ENTROPY_PATH=${LUET_ENTROPY_PATH:-tree/sabayonlinux.org}

git clone ${LUET_ENTROPY_REPO} repo

wget https://dispatcher.sabayon.org/sbi/namespace/luet-cross-bin/luet-latest-amd64 -O ./luet
chmod a+x ./luet

# Build packages list
pkgs="$(./luet tree pkglist -t ./repo/${LUET_ENTROPY_PATH} ${LUET_EXCLUDES} -v)"
n_pkgs="$(./luet tree pkglist -t ./repo/${LUET_ENTROPY_PATH} ${LUET_EXCLUDES} -v | wc -l)"
equo update && equo upgrade
equo i ${pkgs}

equo cleanup
rm -rf ./repo ./luet ./installer.sh

echo "Installed $n_pkgs!"
