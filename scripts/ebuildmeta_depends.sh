#!/bin/bash
# Example on how to use:
# docker build --rm -t ebuild2spec .
# With existing specs:
#  docker run -ti -v $PWD:/test/ --rm ebuild2spec app-cdr/brasero /test/definition.yaml /test/build.yaml
# Without existing specs:
#  docker run -ti -v $PWD:/test/ --rm ebuild2spec app-cdr/brasero

PACKAGE=$1
RUNTIME_FILE=$2
BUILDTIME_FILE=$3

generate_requires() {
    local deps=$1
    REQUIRES=$(yq n requires '')
    count=0
    declare -A visited
    for i in $deps; do
        name=$(pkgs-checker pkg info $i | grep "name:" --color=none | awk '{ print $2 }')
        category=$(pkgs-checker pkg info $i | grep "category:" --color=none | awk '{ print $2 }')
        version=$(pkgs-checker pkg info $i | grep "version:" --color=none | awk '{ print $2 }')
        slot=$(pkgs-checker pkg info $i | grep "slot:" --color=none | awk '{ print $2 }')
        slot=$(echo "${slot}" | sed 's:/.*::g' | sed 's:=.*::g') # Drop subslots
        if [[ -z "$version" ]]; then
            version="0"
        fi
        if [[ -n "$slot" ]] && [[ "$slot" != "0" ]]; then
            name="$name-$slot"
        fi

        if [[ -n "$category" ]] && [[ -n "$name" ]] \
           && [[ "${visited[$category/$name]}" != "true" ]]; then
            REQUIRES=$(echo "$REQUIRES" | yq w - requires[+].name $name)
            REQUIRES=$(echo "$REQUIRES" | yq w - requires[$count].category $category)
            REQUIRES=$(echo "$REQUIRES" | yq w - requires[$count].version ">=0")
            
            count=$(($count+1))
            visited["$category/$name"]=true
        fi
    done
    echo "$REQUIRES"
}

# Get specific package version from portage
package=`cat <<EOF
import portage

p = portage.db[portage.root]["porttree"].dbapi
print(p.match("$PACKAGE")[-1])
EOF
`
PACKAGE=$(python -c "$package")

echo "Package $PACKAGE"

# Get RDEPEND/DEPEND list
RDEPEND=`cat <<EOF
import portage

p = portage.db[portage.root]["porttree"].dbapi
pack = p.match("$PACKAGE")[-1]
print(p.aux_get(pack, ["RDEPEND"]))
EOF
`

DEPEND=`cat <<EOF
import portage
p = portage.db[portage.root]["porttree"].dbapi
pack = p.match("$PACKAGE")[-1]

print(p.aux_get(pack, ["DEPEND"]))
EOF
`

# Sanitize Portage API output
# The perl regex removes any dependency which is
# in the form and cleans the output:
#  use ? ( foo )
RUNTIME_DEP=$(python -c "$RDEPEND" | perl -nle "s/\(.*?\)|\s(!?\w+)\?|^\[\'|\'\]$|\[.*?\]//g; print $_")
BUILDTIME_DEP=$(python -c "$DEPEND" | perl -nle "s/\(.*?\)|\s(!?\w+)\?|^\[\'|\'\]$|\[.*?\]//g; print $_")

# Convert to yaml
echo
echo "Runtime"
GENERATED_RUNTIME=$(generate_requires "$RUNTIME_DEP")
echo "$GENERATED_RUNTIME"

echo
echo "Build time"
GENERATED_BUILDTIME=$(generate_requires "$BUILDTIME_DEP")
echo "$GENERATED_BUILDTIME"

# Merge new data back to provided files (if any)
if [[ -n "$RUNTIME_FILE" ]]; then
    echo "$GENERATED_RUNTIME" | yq m -i -x "$RUNTIME_FILE" -
fi

if [[ -n "$BUILDTIME_FILE" ]]; then
    echo "$GENERATED_BUILDTIME" | yq m -i -x "$BUILDTIME_FILE" -
fi
