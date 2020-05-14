# luet-entropy-repo
[![Docker Repository on Quay](https://quay.io/repository/luet/entropy-minimal/status "Docker Repository on Quay")](https://quay.io/repository/luet/entropy-minimal)

Luet specs repository based on entropy packages.

## Tips and tricks

### Remove a runtime dependencies from all the specs

Requires yq installed.

```find ./ -path '*/definition.yaml' -type f -exec yq d -i {} 'requires.(name==gettext)' \;```

replace "gettext" with the name of the package you wish to delete. Similarly you can use other fields (`name` in the following example) to
match the deletion criteria
