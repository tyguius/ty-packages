#!/bin/bash

source ./ty-frame.sh
export PACKAGER="tyguius <ta.tgyns13@gmail.com>"
export PKGDEST="$HOME/Tyrepo"
if [ -z "$1" ]
then
    echo "re-releasing complete database"
    for directory in $(ls -d */)
        do
            cd "$directory"
            tyguius_make_package
            cd ..
    done
    tyguius_tyrepo_update
else
    cd ./"$1"
    if [ "$?" -ne "0" ]
    then
        echo "package does not exist"
    else
        if prompt_confirmation "New Release?"
        then
            changes="-release"
        else
            changes="$(force_read "Describe changes: ")"
        fi
            tyguius_make_package "$changes"
            tyguius_tyrepo_update "$changes"
    fi

fi





