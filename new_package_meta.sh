#!/bin/bash
read -p "Please enter package name: " NAME

mkdir "$NAME"

read -p "Please enter depencencies: " -a DEPENDENCIES

read -p "Please enter a package description: " DESCRIPTION

for DEPENDENCY in "${DEPENDENCIES[@]}"
do
    echo "$DEPENDENCY" >> "$NAME/$NAME.depends"
done

cp PKGBUILD_template-meta "$NAME/PKGBUILD"

sed "/^pkgname=/s/\"\"/\"$NAME\"/" -i "$NAME/PKGBUILD"

sed "/^pkgdesc=/s/\"\"/\"$DESCRIPTION\"/" -i "$NAME/PKGBUILD"

sed "/^pkgver=/s/0.0.0.0/0.0.0.1/" -i "$NAME/PKGBUILD"
