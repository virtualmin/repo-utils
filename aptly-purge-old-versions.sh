#!/usr/bin/bash
# Removes old packages in the received repo
#
# $1: Repository
# $2: Architecture
# $3: Amount of packages to keep
repo_remove_old_packages() {
    local repo=$1
    local arch=$2
    local keep=$3

    for pkg in $(aptly repo search $repo "Architecture ($arch)" | grep -v "ERROR: no results" | sort -rV); do
        local pkg_name=$(echo $pkg | cut -d_ -f1)
        if [ "$pkg_name" != "$cur_pkg" ]; then
            local count=0
            local deleted=""
            local cur_pkg="$pkg_name"
        fi
        test -n "$deleted" && continue
        let count+=1
        if [ $count -gt $keep ]; then
            pkg_version=$(echo $pkg | cut -d_ -f2)
            aptly repo remove $repo "Name ($pkg_name), Version (<= $pkg_version)"
            deleted='yes'
        fi
    done
}

repo_remove_old_packages $1 $2 $3
