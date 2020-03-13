#!/bin/bash
ROOT_DIR=$(git rev-parse --show-toplevel)

for i in $(ls $ROOT_DIR/tree/sabayonlinux.org/acct-group);do 
echo "Converting $i"

bash -i $ROOT_DIR/scripts/generate-entities.sh acct-group/$i $ROOT_DIR/tree/sabayonlinux.org/acct-group/$i/1

done

for i in $(ls $ROOT_DIR/tree/sabayonlinux.org/acct-user);do 
echo "Converting $i"

bash -i $ROOT_DIR/scripts/generate-entities.sh acct-user/$i $ROOT_DIR/tree/sabayonlinux.org/acct-user/$i/1

done