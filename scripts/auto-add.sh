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

# Get template used to update build specs
PRELUDE=$(cat $PRELUDE_TEMPLATE)


# Luet tree package list
PKG_LIST=$(luet tree pkglist --tree $ROOT_DIR/tree -o json)

# Functions to retrieve all packages
all_sabayon() {

    echo $(curl -s -d "repo=${SABAYON_DATABASE}&repository_type=sabayon" \
            -X POST "${PKGAPI}/api/all" \
            | jq -r '.Packages[]')
}

all_gentoo() {

    echo $(curl -s -d "repo=gentoo&owner=gentoo&repository_type=gentoo" \
            -X POST "${PKGAPI}/api/latest" \
            | jq -r '.Packages[]')
}


luet_package_exists() {
    local name=$1
    local category=$2
    if [[ $(echo "$PKG_LIST" | jq ".packages[] | select(.name==\"$name\") | select(.category==\"$category\")") != "" ]]; then
    echo true
    else
    echo false
    fi
}


ALL_PACKAGES=
if [[ "$STRATEGY" == "gentoo" ]];
then
    ALL_PACKAGES=$(all_gentoo)
fi
if [[ "$STRATEGY" == "sabayon" ]];
then
    ALL_PACKAGES=$(all_sabayon)
fi

for i in $(echo "$ALL_PACKAGES" | jq -r '.Category + "/" +.Name + "/" +.Version '); do
    
    set -f                      # avoid globbing (expansion of *).
    pack=(${i//\// })
    PACKAGE_CAT=${pack[0]}
    PACKAGE_N=${pack[1]}
    PACKAGE_V=${pack[2]}
    set +f
    echo "Checking if package in $PACKAGE_CAT named $PACKAGE_N exists"
    if [[ $(luet_package_exists "$PACKAGE_N" "$PACKAGE_CAT" "$PKG_LIST") == "true" ]]; then
        echo "  exists"
        continue
    fi
    echo "  doesn't exists - creating it"

    BRANCH_NAME="create_${PACKAGE_CAT}_${PACKAGE_N}"
    if [ "${AUTO_GIT}" == "true" ]; then
        git branch -D $BRANCH_NAME || true
        git checkout -b $BRANCH_NAME
    fi

    mkdir -p $ROOT_DIR/tree/$PACKAGE_CAT/$PACKAGE_N/$PACKAGE_V
    DEFINITION_FILE=$ROOT_DIR/tree/$PACKAGE_CAT/$PACKAGE_N/$PACKAGE_V/definition.yaml
    BUILD_FILE=$ROOT_DIR/tree/$PACKAGE_CAT/$PACKAGE_N/$PACKAGE_V/build.yaml
    touch $DEFINITION_FILE
    touch $BUILD_FILE
    yq w -i $DEFINITION_FILE name "$PACKAGE_N" --style double
    yq w -i $DEFINITION_FILE 'labels."original.package.name"' "$PACKAGE_N" --style double

    yq w -i $DEFINITION_FILE category "$PACKAGE_CAT" --style double
    yq w -i $DEFINITION_FILE 'labels."original.package.category"' "$PACKAGE_CAT" --style double

    yq w -i $DEFINITION_FILE version "$PACKAGE_V" --style double
    yq w -i $DEFINITION_FILE 'labels."original.package.version"' "$PACKAGE_V" --style double

    docker run -v $ROOT_DIR/tree:/tree -ti --rm quay.io/luet/ebuildmeta2spec \
        $PACKAGE_CAT/$PACKAGE_N \
        /tree/$PACKAGE_CAT/$PACKAGE_N/$PACKAGE_V/definition.yaml \
        /tree/$PACKAGE_CAT/$PACKAGE_N/$PACKAGE_V/build.yaml

    yq w -i $BUILD_FILE env.[0] "ORIGINAL_ATOM=$PACKAGE_CAT/$PACKAGE_N"
    yq w -i $BUILD_FILE env.[1] "ORIGINAL_PACKAGE=$PACKAGE_CAT/$PACKAGE_N-$PACKAGE_V"
    yq w -i $BUILD_FILE steps.[0] "$STEP" --style folded
    yq w -i $BUILD_FILE prelude.[0] "$PRELUDE" --style folded

    if [ "${AUTO_GIT}" == "true" ]; then
            git add $ROOT_DIR/tree/$PACKAGE_CAT/$PACKAGE_N/
            git commit -m "Add $PACKAGE_CAT/$PACKAGE_N at $PACKAGE_V"
            git push -f -v origin $BRANCH_NAME

            # Branch is ready now to open PR
            hub pull-request $HUB_ARGS -m "$(git log -1 --pretty=%B)"
            git checkout $START_GIT_BRANCH # Return to original branch
    fi
done
