#!/bin/bash

CURRENT_DIR=$(cd `dirname "$0"`; pwd)
DIR=/tmp/images


# create if /sources/icons/ does not exist
echo "Checking if "$CURRENT_DIR"/sources/icons/ exist ..."
if [ ! -d "$CURRENT_DIR"/sources/icons ]; then
    mkdir "$CURRENT_DIR"/sources/icons
    echo "Created /sources/icons/ ..."
fi

#check if svn is installed, if not them prompt to install

if [[ -z $(which svn) ]]; then
    echo "Subversion is not installed."
    read -p "Do you wish to install this program?[Y/n]" yn
    case $yn in
        [Yy]* ) sudo apt-get install subversion;;
        [Nn]* ) exit;;
        * ) echo "Please answer yes or no.";;
    esac
fi


# delete if DIR=/tmp/images already exist

if [ -d "$DIR" ]; then
    rm -rf "$DIR"
fi

#svn checkout the images to DIR=/tmp/images
svn checkout https://github.com/synfig/synfig/trunk/synfig-studio/images /tmp/images/


#cd to the DIR and copt them to /sources/icons/
cd "$DIR"
for f in *.sif
do 
   cp -v "$f" "$CURRENT_DIR"/sources/icons/
done



