#!/bin/bash
set -e

if [ -d "$ROOT_DIR" ]; then
  git clone https://github.com/Luet-lab/luet-repo $ROOT_DIR/luet-repo
fi

if [ -d "$ROOT_DIR/luet-repo" ]; then
  $LUET tree validate --tree $ROOT_DIR/$TREE --tree $ROOT_DIR/luet-repo -s
else
  echo "luet-repo missing: bailing out"
  exit 1
fi
