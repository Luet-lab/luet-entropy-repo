#!/bin/bash

# Author: Daniele Rondina <geaaru@sabayonlinux.org>
# Description: Script for create luet specs for a list of packages
#              available through an entropy repository.

REPOSITORY=${REPOSITORY:-sabayonlinux.org}
TARGET_DIR=${TARGET_DIR:-tree/${REPOSITORY}}
PACKAGES=${PACKAGES:-""}
DOWNLOAD_LATEST_PKGS_CHECKER=${DOWNLOAD_LATEST_PKGS_CHECKER:-0}
DEBUG_BUMP=${DEBUG_BUMP:-0}
PARALLEL_ENABLE=${PARALLEL_ENABLE:-0}
PARALLEL_JOBS=${PARALLEL_JOBS:-40}
BACKGROUND_MODE=${BACKGROUND_MODE:-0}
ENTROPY_DB=${ENTROPY_DB:-/var/lib/entropy/client/database/amd64/equo.db}
PKG_SLOT_SEPARATOR=${PKG_SLOT_SEPARATOR:--}


process_package () {
  local pkg=$1

  # Retrieve package detail
  local name=$(pkgs-checker pkg info $pkg | grep "name:" --color=none | awk '{ print $2 }')
  local cat=$(pkgs-checker pkg info $pkg | grep "category:" --color=none | awk '{ print $2 }')
  local version=$(pkgs-checker pkg info $pkg | grep "version:" --color=none | awk '{ print $2 }')
  local ver_suffix=$(pkgs-checker pkg info $pkg | grep "version_suffix" --color=none | awk '{ print $2 }')
  local ver_build=$(pkgs-checker pkg info $pkg | grep "version_build" --color=none | awk '{ print $2 }')

  ver_suffix=${ver_suffix/-}
  ver_suffix=${ver_suffix/_}

  # Skip virtual packages
  if [[ $cat = "virtual" ]] ; then
    echo "Package $pkg is skipped."
    return 0
  fi

  local build_symbol=""
  if [[ -n "${ver_suffix}" || -n "${ver_build}" ]] ; then
    build_symbol="+"
  fi

  # Check slot
  local slot=$(pkgs-checker entropy info $pkg -d $ENTROPY_DB | grep slot | head -n 1 | awk '{ print $2 }')

  # Ignore sub-slot for now.
  slot=$(echo "${slot}" | sed 's:/.*::g')
  local luet_name="${name}"
  if [ "$slot" != "0" ] ; then
    luet_name="${name}${PKG_SLOT_SEPARATOR}${slot}"
  fi

  local pkgdir="${cat}/${luet_name}/${version}"

  echo "Analyzing package $pkg ..."

  # Check if package is already present
  if [ -d ${pkgdir} ] ; then

      echo "
Labels:
  original.package.name: "${name}"
  original.package.category: "${cat}"
  original.package.version: "${version}${version_suffix}"
  original.package.slot: "${slot}"
" >> $pkgdir/definition.yaml
  fi

  echo "1" > ${COUNTERDIR}/${cat}-${name}-${version}

  return 0
}

process_packages () {

  if [ -z "${PACKAGES}" ] ; then
    # I use installed packages
    PACKAGES=$(equo q list installed ${REPOSITORY} -q -v)
  fi

  COUNTERDIR=$(mktemp -d)

  if [ "$PARALLEL_ENABLE" = "1" ] ; then
    export COUNTERDIR
    export DEBUG_BUMP
    export ENTROPY_DB
    export REPOSITORY
    export PKG_SLOT_SEPARATOR
    export -f process_package
    parallel -j ${PARALLEL_JOBS} --will-cite -k process_package ::: ${PACKAGES}
  else
    for p in ${PACKAGES} ; do
      if [ $BACKGROUND_MODE = "1" ] ; then
        process_package $p &
      else
        process_package $p
      fi
    done

    wait
  fi

  local N_PKGS=$(ls -l ${COUNTERDIR} | wc -l)

  echo "Updated ${N_PKGS} packages!"

  rm -rf ${COUNTERDIR}

  return 0
}

main () {

  if [ ! -e $TARGET_DIR ] ; then
    mkdir -p ${TARGET_DIR}
  fi

  if [ ${DOWNLOAD_LATEST_PKGS_CHECKER} = "1" ] ; then
    # Download latest version of pkgs-checker
    wget https://dispatcher.sabayon.org/sbi/namespace/pkgs-checker-cross-bin/pkgs-checker-latest-linux-amd64 -O /usr/bin/pkgs-checker
    chmod a+x /usr/bin/pkgs-checker
  fi

  pushd ${TARGET_DIR}
    process_packages || return 1
  popd

  return 0
}

main
exit $?
