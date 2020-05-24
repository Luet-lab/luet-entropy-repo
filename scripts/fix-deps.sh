#!/bin/bash
#set -ex
# Auto add script by Ettore Di Giacinto <mudler@sabayonlinux.org>
# License: MIT
# This script does one thing:
# 1) checks new version upstream, and creates a new package if not existing
# Requires yq and jq

# Options
PKGAPI="${PKGAPI:-https://pkgapi.herokuapp.com}"
SABAYON_DATABASE="${SABAYON_DATABASE:-http://sabayonlinux.mirror.garr.it/sabayonlinux/entropy/standard/sabayonlinux.org/database/amd64/5/packages.db.bz2}"
STRATEGY="${STRATEGY:-sabayon}"
STEP_TEMPLATE="${STEP_TEMPLATE:-$ROOT_DIR/scripts/templates/sabayon_prelude.tmpl}"
PRELUDE_TEMPLATE="${PRELUDE_TEMPLATE:-$ROOT_DIR/scripts/templates/sabayon_step.tmpl}"
FILTER="${FILTER:-}"

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

# Luet tree package list
PKG_LIST=$(luet tree pkglist --tree $ROOT_DIR/tree -o json)

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

    # Filter packages
    if [ -n "$FILTER" ] && [ "$PACKAGE_CATEGORY" != "$FILTER" ]; then
        continue
    fi

    PACKAGE_CAT=$ORIGINAL_PACKAGE_CATEGORY
    PACKAGE_N=$ORIGINAL_PACKAGE_NAME
    PACKAGE_V=$ORIGINAL_PACKAGE_VERSION
    set +f

    BRANCH_NAME="fix_${PACKAGE_CAT}_${PACKAGE_N}"
    if [ "${AUTO_GIT}" == "true" ]; then
        git branch -D $BRANCH_NAME || true
        git checkout -b $BRANCH_NAME
    fi

    DEFINITION_FILE=$PACKAGE_PATH/definition.yaml
    BUILD_FILE=$PACKAGE_PATH/build.yaml

    docker run -v $ROOT_DIR/tree:/tree -ti --rm quay.io/luet/ebuildmeta2spec \
        $PACKAGE_CAT/$PACKAGE_N \
        /tree/sabayonlinux.org/$PACKAGE_CATEGORY/$PACKAGE_NAME/$VERSION/definition.yaml 

    if [ "${AUTO_GIT}" == "true" ]; then
            git add $ROOT_DIR/tree/$PACKAGE_PATH
            git commit -m "Fix Deps of $PACKAGE_CAT/$PACKAGE_N"
            git push -f -v origin $BRANCH_NAME

            # Branch is ready now to open PR
            hub pull-request $HUB_ARGS -m "$(git log -1 --pretty=%B)"
            git checkout $START_GIT_BRANCH # Return to original branch
    fi
done
