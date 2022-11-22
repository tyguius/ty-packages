#!/bin/bash
prompt_confirmation() {
    read -p "$1 [Y/n]" -n 1
    echo
    if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]
    then
        true
    elif [[ $REPLY =~ ^[Nn]$ ]]
    then
        false
    else
        prompt_confirmation "$1"
    fi
}

force_read() {
    read -p "$1"
    if [ -n "$REPLY" ]
    then
        echo "$REPLY"
    else
        force_read "$1"
    fi
}

# use $pkgname.txt if exists
# STUB
depends_from_file() {
    [[ -f "$1.txt" ]] && depends=($(grep -v "^#" "$1.txt"))
}

# use $pkgname.sources if exists
sources_from_file() {
    [[ -f "$1.sources" ]] && source=($(grep -v "^#" "$1.sources"))
}

# sources_from_dir() {
#     if [[ -d src ]]
#     then
#         cd src
#         sources=$(ls)
#     fi
# }

install_hooks_from_file() {
    [[ -f "$1.install" ]] && install="$1.install"
}

make_pkg_dir() {
    mkdir -p "${pkgdir}$1"
}

update_pkgrel() {
    pkgrel=$((pkgrel+1))
    sed -i -e "/^pkgrel=/s|.*|pkgrel=$pkgrel|" PKGBUILD
}

update_pkgver() {
    read -p "current version $pkgver. Set new version: "
    pkgver="$REPLY"
    sed -i -e "/^pkgver=/s|.*|pkgver=$pkgver|" PKGBUILD
    sed -i -e "/^pkgrel=/s|.*|pkgrel=0|" PKGBUILD
}

tyguius_make_package() {
    local changes=$1
    updpkgsums
    source ./PKGBUILD
    if [ -z "$changes" ] || [ "$changes" = "-release" ]
    then
        update_pkgrel
    else
        update_pkgver
    fi
    source ./PKGBUILD
    cd ..
    git add .
    git tag "$pkgname-$pkgver-$pkgrel"
    if [ -z "$changes" ] || [ "$changes" = "-release" ]
    then
        git commit -m "Auto commit on build of new release. $pkgname-$pkgver-$pkgrel"
    else
        git commit -m "$pkgname-$pkgver-$pkgrel: $changes"
    fi
    git push -u origin master
    cd $pkgname
    export SRCDEST="./src"
    export SRCPKGDEST="./pkg"
    if ! makepkg
    then
        echo "makepkg not succesfull"
        exit 1
    fi

}

tyguius_tyrepo_update() {
    local changes=$1
    if [ -z "$changes" ]
    then
        cd ~/Tyrepo
        repo-add tyrepo.db.tar.xz *.pkg.tar.zst
        git add .
        git commit -m "tyrepo updated "
        git push -u origin master
    else
        source ./PKGBUILD
        cd ~/Tyrepo
        local package="$pkgname-$pkgver-$pkgrel-$arch.pkg.tar.zst"
        repo-add tyrepo.db.tar.xz "$package"
        git add .
        if [ "$changes" = "-release" ]
        then
            git commit -m "$pkgname-$pkgver release $pkgrel"
        else
            git commit -m "$changes in $package"
        fi
        git push -u origin master
    fi
}




# update version, add, commit and push
# update_pkg_version() {
#     if [[ -s version ]]
#     then
#         get_pkg_version
#         echo "Current version: $version"
#         if prompt_confirmation "New Release?"
#         then
#             pkgrel=$((pkgrel+1))
#         else
#             set_pkg_version
#         fi
#     else
#         echo "No version set"
#         set_pkg_version
#     fi
#     version="$pkgver-$pkgrel"
#     echo "$version" > version
#     git add .
#     git commit -m "auto-commit $version"
#     git push -u origin master
#     git tag "$version"
#     echo "Version set and tagged to: $version"
# }
# get_pkg_version() {
#     version="$(cat version)"
#     pkgver="${version%%-*}"
#     pkgrel="${version##*-}"
# }
# # prompt user to set version
# set_pkg_version() {
#     read -p "Set version: ( x / x.x / x.x.x etc. )"
#     pkgver=$REPLY
#     pkgrel=1
# }




#ty_makepkg() {
  #  BUILDDIR=~/tyrepo/build

   # makepkg
#}
