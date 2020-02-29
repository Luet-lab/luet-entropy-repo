#!/bin/bash

# Author: Daniele Rondina <geaaru@sabayonlinux.org>
# Description: Script for create luet specs for a list of packages
#              available through an entropy repository.

REPOSITORY=${REPOSITORY:-sabayonlinux.org}
TARGET_DIR=${TARGET_DIR:-tree/${REPOSITORY}}
PACKAGES=${PACKAGES:-""}
DOWNLOAD_LATEST_PKGS_CHECKER=${DOWNLOAD_LATEST_PKGS_CHECKER:-0}

N_PKGS=0

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
  if [[ $cat = "virtual" || $cat == "acct-group" || $cat == "acct-user" ]] ; then
    echo "Package $pkg is skipped."
    return 0
  fi

  local pkgdir="${cat}/${name}/${version}"

  echo "Analyzing package $pkg with dir ${pkgdir}..."

  # Check if package is already present
  if [ -d ${pkgdir} ] ; then
    # nothing to do
    echo "Package $pkg is already present. Nothing to do."

    return 0
  fi

  mkdir -p ${pkgdir}

  includes=$(equo q files $pkg -q)

  deps=$(equery g $pkg -l -M -U --depth=3 -A | grep " \[" --color=none | awk '{ print $3 }' | sed 's/\x1B\[[0-9;]\+[A-Za-z]//g')

  local build_symbol=""
  if [[ -n "${ver_suffix}" || -n "${ver_suffix}" ]] ; then
    build_symbol="+"
  fi

  echo "
category: \"${cat}\"
name: \"${name}\"
version: \"${version}${build_symbol}${ver_suffix}${version_build}\"" > $pkgdir/definition.yaml

  echo "
steps:
- source /etc/profile && equo up
- ACCEPT_LICENSE=* equo i gentoolkit ${pkg}
image: \"sabayon/base\"
includes:" > $pkgdir/build.yaml

  for inc in ${includes} ; do
    echo "- ${inc}$" >> $pkgdir/build.yaml
  done

  echo "requires:" >> $pkgdir/definition.yaml
  local dep_name=""
  local dep_cat=""
  local dep_version=""
  for dep in ${deps} ; do

    dep_name=$(pkgs-checker pkg info $dep | grep "name:" --color=none | awk '{ print $2 }' | sed 's/\x1B\[[0-9;]\+[A-Za-z]//g')
    dep_cat=$(pkgs-checker pkg info $dep | grep "category:" --color=none | awk '{ print $2 }' | sed 's/\x1B\[[0-9;]\+[A-Za-z]//g')
    dep_version=$(pkgs-checker pkg info $dep | grep "version:" --color=none | awk '{ print $2 }' | sed 's/\x1B\[[0-9;]\+[A-Za-z]//g')

    if [ "${dep_cat}/${dep_name}" = "${cat}/${name}" ] ; then
      continue
    fi

    if [ "${dep_cat}" = "virtual" ] ; then
      continue
    fi
    if [[ "${dep_cat}" = "virtual" || "${dep_cat}" == "acct-group" || "${dep_cat}" == "acct-user" ]] ; then
      continue
    fi

    echo "- category: \"${dep_cat}\"
  name: \"${dep_name}\"
  version: \">=${dep_version}\"" >> $pkgdir/definition.yaml
  done

  let N_PKGS++

  return 0
}

process_packages () {

  if [ -z "${PACKAGES}" ] ; then
    # I use installed packages
    PACKAGES=$(equo q list installed ${REPOSITORY} -q -v)
  fi

  for p in ${PACKAGES} ; do
    process_package $p
  done

  echo "Added ${N_PKGS} packages!"

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
