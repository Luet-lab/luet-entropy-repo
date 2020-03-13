#!/bin/bash
# Author: Ettore Di Giacinto <mudler@sabayonlinux.org>
# Converts acct-user/acct-group packages to entities
# Don't run this script on the local system. It downloads and evals remote content.
# Consider yourself warned

set -e

# e.g. <0> acct-user/amule output

PACKAGE="${1}"
OUT="${2}"
BUILD_DEP_CAT="${BUILD_DEP_CAT:-distro}"
BUILD_DEP_NAME="${BUILD_DEP_NAME:-alpine}"
BUILD_DEP_VERSION="${BUILD_DEP_VERSION:-3.11.3}"
ENTITIY_PACKAGE_VERSION="${ENTITY_PACKAGE_VERSION:-1}"

PACKAGE_NAME="$(echo $PACKAGE | grep -oP '.*\/\K.*')"
EBUILD="$PACKAGE_NAME-0.ebuild"
content=$(curl -s "https://raw.githubusercontent.com/gentoo/gentoo/master/${PACKAGE}/${EBUILD}")

## Shadow eclass functions
inherit() {
echo > /dev/null
}

acct-user_add_deps() {
echo > /dev/null
}

mkdir -p ${OUT} || true
if [[ "$PACKAGE" == acct-user* ]]; then

    : ${ACCT_USER_ENFORCE_ID:=}
    : ${ACCT_USER_SHELL:=-1}
    : ${ACCT_USER_HOME:=/dev/null}
    : ${ACCT_USER_HOME_PERMS:=0755}

    echo "User package"
    eval "$content"
    echo $ACCT_USER_ID
    echo $ACCT_USER_GROUPS
group=$(curl -s "https://raw.githubusercontent.com/gentoo/gentoo/master/acct-group/$PACKAGE_NAME/${EBUILD}")
    eval "$group"

if [ "$ACCT_USER_SHELL" == "-1" ];
then
ACCT_USER_SHELL="/sbin/nologin"
fi
cat << EOF > $OUT/${PACKAGE_NAME}_entity_add.yaml
kind: "user"
username: "${PACKAGE_NAME}"
password: "x"
uid: $ACCT_USER_ID
gid: ${ACCT_GROUP_ID}
info: "Created by entities"
homedir: "$ACCT_USER_HOME"
shell: "${ACCT_USER_SHELL}"
EOF


cat << EOF >> $OUT/definition.yaml
category: "acct-user"
name: "${PACKAGE_NAME}"
version: "${ENTITIY_PACKAGE_VERSION}"
requires:
- category: "acct-group"
  name: "${PACKAGE_NAME}"
  version: ">=0"
- category: "system"
  name: "entities"
  version: ">=0.1"
EOF

cat << EOF >> $OUT/build.yaml
steps:
- mkdir /etc/entities/|| true
- cp -rfv ${PACKAGE_NAME}*.yaml /etc/entities/
requires:
- category: "$BUILD_DEP_CAT"
  name: "${BUILD_DEP_NAME}"
  version: "${BUILD_DEP_VERSION}"
EOF

for i in "${ACCT_USER_GROUPS[@]}"
do
   : 
    cat << EOF > $OUT/${PACKAGE_NAME}_group_entity_apply_$i.yaml
kind: "group"
group_name: "${i}"
users: "${PACKAGE_NAME}"
EOF
done

cat << EOF > $OUT/finalize.yaml
install:
- entities create -f /etc/passwd /etc/entities/${PACKAGE_NAME}_entity_add.yaml || true
EOF
for i in "${ACCT_USER_GROUPS[@]}"
do
   : 
echo "- entities apply -f /etc/group /etc/entities/${PACKAGE_NAME}_group_entity_apply_$i.yaml" >> $OUT/finalize.yaml
done

elif [[ "$PACKAGE" == acct-group* ]]; then

    echo "Group package"
    eval "$content"
    echo ${ACCT_GROUP_NAME}
    echo ${ACCT_GROUP_ID}

cat << EOF > $OUT/${PACKAGE_NAME}_acct-group_entity.yaml
kind: "group"
group_name: "${PACKAGE_NAME}"
gid: ${ACCT_GROUP_ID}
EOF

cat << EOF >> $OUT/definition.yaml
category: "acct-group"
name: "${PACKAGE_NAME}"
version: "${ENTITIY_PACKAGE_VERSION}"
requires:
- category: "system"
  name: "entities"
  version: ">=0.1"
EOF

cat << EOF >> $OUT/build.yaml
steps:
- mkdir /etc/entities/|| true
- cp -rfv ${PACKAGE_NAME}*.yaml /etc/entities/
EOF

cat << EOF > $OUT/finalize.yaml
install:
- entities create -f /etc/group /etc/entities/${PACKAGE_NAME}_acct-group_entity.yaml || true
EOF
else 
    echo "Unsupported package"
    exit 1
fi
