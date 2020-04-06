#!/bin/bash
ROOT_DIR=$(git rev-parse --show-toplevel)

for i in $(curl -s -H "Authorization: token ${GITHUB_TOKEN}" https://api.github.com/repos/gentoo/gentoo/contents/acct-group | jq -r '.[].name');do
echo "Converting $i"
bash -i $ROOT_DIR/scripts/generate-entities.sh acct-group/$i $ROOT_DIR/tree/sabayonlinux.org/acct-group/$i/0
done

for i in $(curl -s -H "Authorization: token ${GITHUB_TOKEN}" https://api.github.com/repos/gentoo/gentoo/contents/acct-user | jq -r '.[].name');do
echo "Converting $i"
bash -i $ROOT_DIR/scripts/generate-entities.sh acct-user/$i $ROOT_DIR/tree/sabayonlinux.org/acct-user/$i/0
done
