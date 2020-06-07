#!/bin/sh

# Make sure slib is up to date
cd $HOME/src/slib
git checkout master
git pull
tag=`git describe --abbrev=0 --tags`
git checkout tags/$tag
cp slib.sh $HOME/result/lib

