#!/bin/bash

LUET_ENTROPY_REPO=${LUET_ENTROPY_REPO:-https://github.com/Luet-lab/luet-entropy-repo.git}

equo update && equo upgrade
n_pkgs=$(cat ./pkglist | wc -l)
equo i `cat ./pkglist | xargs echo`

equo cleanup

rm ./installer.sh ./pkglist
echo "Installed $n_pkgs!"
