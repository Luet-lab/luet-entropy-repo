# luet-entropy-repo
[![Docker Repository on Quay](https://quay.io/repository/luet/entropy-minimal/status "Docker Repository on Quay")](https://quay.io/repository/luet/entropy-minimal)

Luet specs repository based on entropy packages.

## Tips and tricks

### Remove a runtime dependencies from all the specs

Requires yq installed.

```
find ./ -path '*/definition.yaml' -type f -exec yq d -i {} 'requires.(name==gettext)' \;
```

replace "gettext" with the name of the package you wish to delete. Similarly you can use other fields (`name` in the following example) to
match the deletion criteria

### Clean definition from null labels on deps

```
$> sed -e '/- labels\: null/d' -e 's|  category:|- category:|g' $SPECFILE
```

Or for all the tree:

```
$> for i in `grep "labels: null" * -r -l tree/` ; do sed -e '/- labels\: null/d' -e 's|  category:|- category:|g' -i $i ; done

```

### Find specs with duplicated labels

```
$> for i in `find  tree/ -name '*.yaml' ` ; do n_labels=$(cat $i | grep '^labels' | wc -l) ; if [ $n_labels -ge 2 ] ; then echo $i ; fi ; done
```

### Retrieve list of files of a package for build.yaml

```
$> for i in `qlist =${P}` ; do echo "- $i$" ; done
```
Note: Directories must be added manually.
