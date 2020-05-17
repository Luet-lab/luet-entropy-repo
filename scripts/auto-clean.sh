#!/bin/bash
#set -ex
# Auto bumper script by Ettore Di Giacinto <mudler@sabayonlinux.org>
# License: MIT
# This script does two thing:
# 1) checks new version upstream, and bump the version if not matching (excluding "+" in the version)
# 2) if new versions are there, it also bumps all the revdeps for a forced rebuild.
# Requires yq and jq

# Options
PKGAPI="${PKGAPI:-https://pkgapi.herokuapp.com}"
SABAYON_DATABASE="${SABAYON_DATABASE:-http://sabayonlinux.mirror.garr.it/sabayonlinux/entropy/standard/sabayonlinux.org/database/amd64/5/packages.db.bz2}"
VERSIONING_STRATEGY="${VERSIONING_STRATEGY:-sabayon}"
STEP_TEMPLATE="${STEP_TEMPLATE:-$ROOT_DIR/scripts/templates/sabayon_step.tmpl}"
AUTO_GIT="${AUTO_GIT:-false}"

START_GIT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
HUB_ARGS="${HUB_ARGS:--b $START_GIT_BRANCH}"

# Fetch depedendencies if not available
PATH=$PATH:$ROOT_DIR/.bin
hash luet 2>/dev/null || {
    mkdir $ROOT_DIR/.bin/;
    wget https://github.com/mudler/luet/releases/download/0.7.4/luet-0.7.4-linux-amd64 -O $ROOT_DIR/.bin/luet
    chmod +x $ROOT_DIR/.bin/luet
}

hash jq 2>/dev/null || {
    mkdir $ROOT_DIR/.bin/;
    wget https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64 -O $ROOT_DIR/.bin/jq
    chmod +x $ROOT_DIR/.bin/jq
}

hash yq 2>/dev/null || {
    mkdir $ROOT_DIR/.bin/;
    wget https://github.com/mikefarah/yq/releases/download/3.3.0/yq_linux_amd64 -O $ROOT_DIR/.bin/yq
    chmod +x $ROOT_DIR/.bin/yq
}

# Get template used to update build specs
STEP=$(cat $STEP_TEMPLATE)
# Luet tree package list
PKG_LIST=$(luet tree pkglist --tree $ROOT_DIR/tree -o json)

# Functions to retrieve latest package versions
sabayon_versions() {
    NAME=$1
    CATEGORY=$2

    echo $(curl -s -d "repo=${SABAYON_DATABASE}&category=${CATEGORY}&name=${NAME}&repository_type=sabayon" \
            -X POST "${PKGAPI}/api/versions" \
            | jq -r '.Packages | length')
}

gentoo_versions() {
    NAME=$1
    CATEGORY=$2

    echo $(curl -s -d "repo=gentoo&owner=gentoo&category=${CATEGORY}&name=${NAME}&repository_type=gentoo" \
            -X POST "${PKGAPI}/api/versions" \
            | jq -r '.Packages | length')
}

# For each package in the tree, get the path where the spec resides
# e.g. tree/sabayonlinux.org/acct-group/amavis/0/
for i in $(echo "$PKG_LIST" | jq -r '.packages[].path'); do

    PACKAGE_PATH=$i
    PACKAGE_NAME=$(echo "$PKG_LIST" | jq -r ".packages[] | select(.path==\"$i\").name")
    PACKAGE_CATEGORY=$(echo "$PKG_LIST" | jq -r ".packages[] | select(.path==\"$i\").category")
    PACKAGE_VERSION=$(echo "$PKG_LIST" | jq -r ".packages[] | select(.path==\"$i\").version")
    STRIPPED_PACKAGE_VERSION=${PACKAGE_VERSION%\+*}
    VERSION=$STRIPPED_PACKAGE_VERSION

    # Best effort: get original package name from labels
    ORIGINAL_PACKAGE_NAME=$(yq r $PACKAGE_PATH/definition.yaml 'labels."original.package.name"')
    ORIGINAL_PACKAGE_CATEGORY=$(yq r $PACKAGE_PATH/definition.yaml 'labels."original.package.category"')
    ORIGINAL_PACKAGE_VERSION=$(yq r $PACKAGE_PATH/definition.yaml 'labels."original.package.version"')

    if [ -z "$ORIGINAL_PACKAGE_NAME" ]; then
        ORIGINAL_PACKAGE_NAME=$PACKAGE_NAME
    fi
    if [ -z "$ORIGINAL_PACKAGE_CATEGORY" ]; then
        ORIGINAL_PACKAGE_CATEGORY=$PACKAGE_CATEGORY
    fi
    if [ -z "$ORIGINAL_PACKAGE_VERSION" ]; then
        ORIGINAL_PACKAGE_VERSION=$STRIPPED_PACKAGE_VERSION
    fi

    # Get latest version available in repositories
    if [ "${VERSIONING_STRATEGY}" == "all" ]; then
        SABAYON_VERSIONS=$(sabayon_versions $ORIGINAL_PACKAGE_NAME $ORIGINAL_PACKAGE_CATEGORY)
        GENTOO_VERSIONS=$(gentoo_versions $ORIGINAL_PACKAGE_NAME $ORIGINAL_PACKAGE_CATEGORY)
    elif [ "${VERSIONING_STRATEGY}" == "gentoo" ]; then
        GENTOO_VERSIONS=$(gentoo_versions $ORIGINAL_PACKAGE_NAME $ORIGINAL_PACKAGE_CATEGORY)
    elif [ "${VERSIONING_STRATEGY}" == "sabayon" ]; then
        SABAYON_VERSIONS=$(sabayon_versions $ORIGINAL_PACKAGE_NAME $ORIGINAL_PACKAGE_CATEGORY)
    fi

    # We generate acct-group/* and acct-user/*, skip them
    if [ "$PACKAGE_CATEGORY" == "acct-group" ] || [ "$PACKAGE_CATEGORY" == "acct-user" ]; then
        continue
    fi
    echo "==== Package $PACKAGE_CATEGORY/$PACKAGE_NAME ===="

    # No available versions. Delete it!
    if [[ $SABAYON_VERSIONS == "0" ]] || [[ $GENTOO_VERSIONS == "0" ]]; then
        echo "dropping. No versions present"
        BRANCH_NAME="drop_${ORIGINAL_PACKAGE_CATEGORY}_${ORIGINAL_PACKAGE_NAME}"
        if [ "${AUTO_GIT}" == "true" ]; then
            git branch -D $BRANCH_NAME
            git checkout -b $BRANCH_NAME
        fi

        rm -rfv $PACKAGE_PATH

        REVDEP_LIST=$(luet tree pkglist --tree $ROOT_DIR/tree --buildtime --revdeps -m $PACKAGE_CATEGORY/$PACKAGE_NAME -o json --debug=false)
        echo "Revdeps: $REVDEP_LIST" # TODO: Bump revdeps version incrementing value after "+"

        if [ "${AUTO_GIT}" == "true" ]; then
            git add $PACKAGE_PATH
            git commit -m "Drop $ORIGINAL_PACKAGE_CATEGORY/$ORIGINAL_PACKAGE_NAME"
            git push -f -v origin $BRANCH_NAME

            # Branch is ready now to open PR
            hub pull-request $HUB_ARGS -m "$(git log -1 --pretty=%B)"

            git checkout $START_GIT_BRANCH # Return to original branch
        fi

    fi

    echo

done
