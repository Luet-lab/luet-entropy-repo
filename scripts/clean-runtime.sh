#!/bin/bash

# Drop runtime deps by Ettore Di Giacinto <mudler@sabayonlinux.org>
# License: MIT
TO_DROP="$@"
ROOT_DIR=$(git rev-parse --show-toplevel)

# Fetch depedendencies if not available
PATH=$PATH:$ROOT_DIR/.bin
hash yq 2>/dev/null || {
    mkdir $ROOT_DIR/.bin/;
    wget https://github.com/mikefarah/yq/releases/download/3.3.0/yq_linux_amd64 -O $ROOT_DIR/.bin/yq
    chmod +x $ROOT_DIR/.bin/yq
}

for i in $TO_DROP; do
  echo "Dropping any runtime deps for $i in $ROOT_DIR"
  find $ROOT_DIR -path '*/definition.yaml' -type f -exec yq d -i {} 'requires.(name=='$i')'
done

