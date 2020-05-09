#!/bin/bash
# Auto detect script by Ettore Di Giacinto <mudler@sabayonlinux.org>
# License: MIT
# This script does one thing: it compares commits to branch and returns the packages
# that has been touched between the two hash

COMMIT="${COMMIT:-}"
FROM_BRANCH="${FROM_BRANCH:-master}"

ROOT_DIR=${ROOT_DIR:-$PWD}


TO=$(git merge-base "${FROM_BRANCH}" "${COMMIT}")
if [ "$TO" == "$FROM_BRANCH" ]; then
	TO=$COMMIT
fi
# Get the files modified from COMMIT to the base branch (FROM_BRANCH)
file=$(git --no-pager diff --name-only "${FROM_BRANCH}" $TO)

# Fetch depedendencies if not available
PATH=$PATH:$ROOT_DIR/.bin
hash yq 2>/dev/null || {
    mkdir $ROOT_DIR/.bin/;
    wget https://github.com/mikefarah/yq/releases/download/3.3.0/yq_linux_amd64 -O $ROOT_DIR/.bin/yq
    chmod +x $ROOT_DIR/.bin/yq
}

TO_PROCESS=()
TO_REMOVE=()
for f in $file; do

    if [ -f "${f}" ]; then
        #echo "$f exists or has been touched"
        touched_file="$(basename ${f})"
        if [[ "$touched_file" == "build.yaml" ]] || [[ "$touched_file" == "definition.yaml" ]]; then
            TO_PROCESS+=( $(dirname ${f}) )
            #echo "Process $(dirname ${f})"
        fi
    else
        TO_REMOVE+=( $(dirname ${f}) )
        # Todo: remove corresponding packages from the repo
    fi


done

# Get uniques
TO_PROCESS=($(echo "${TO_PROCESS[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
TO_REMOVE=($(echo "${TO_REMOVE[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))

for p in ${TO_PROCESS[@]}; do
   
    ORIGINAL_PACKAGE_NAME=$(yq r $p/definition.yaml 'name')
    ORIGINAL_PACKAGE_CATEGORY=$(yq r $p/definition.yaml 'category')
    ORIGINAL_PACKAGE_VERSION=$(yq r $p/definition.yaml 'version')
    echo "$ORIGINAL_PACKAGE_CATEGORY/$ORIGINAL_PACKAGE_NAME-$ORIGINAL_PACKAGE_VERSION"
done
