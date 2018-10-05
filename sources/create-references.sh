#!/bin/bash

set -x

DEFAULT_VERSION=`cat default-version.txt`

# Get synfig pre-build for default version

mkdir -p /tmp/synfig-$DEFAULT_VERSION
wget "https://sourceforge.net/projects/synfig/files/releases/$DEFAULT_VERSION/linux/synfigstudio-$DEFAULT_VERSION.x86_64.tar.bz2/download" \
	-O "/tmp/synfig-$DEFAULT_VERSION.tar.bz2"

mkdir -p /tmp/synfig-$DEFAULT_VERSION
tar jxf /tmp/synfig-$DEFAULT_VERSION.tar.bz2 -C /tmp


COMPONENTS="blend-methods converters layers"

for COMPONENT in $COMPONENTS; do
  pushd $COMPONENT
    for dir in * ; do
      if [ -d ${dir} ]; then
        pushd $dir

# Check if version file already exist
          if [ -f "$dir.txt" ]; then
            VERSION=`cat $dir.txt`
          else
            VERSION=$DEFAULT_VERSION
          fi

# Check if the required version binaries already exist
          if [ ! -d "/tmp/synfig-$VERSION" ]; then
            wget "https://sourceforge.net/projects/synfig/files/releases/$VERSION/linux/synfigstudio-$VERSION.x86_64.tar.bz2/download" \ 
	    	-O "/tmp/synfig-$DEFAULT_VERSION.tar.bz2"

            mkdir -p /tmp/synfig-$VERSION
            tar jxf /tmp/synfig-$VERSION.tar.bz2 -C /tmp
          fi
          pushd ../../../references
            mkdir -p ./$COMPONENT/$dir
          popd
          CURRENT_DIR=`pwd`
          for sample in * ; do
# Renders every sif file present 
            if [ "${sample##*.}" = "sif" ]; then
              /tmp/synfig-$VERSION/bin/synfig -i $CURRENT_DIR/$sample -o $CURRENT_DIR/../../../references/$COMPONENT/$dir/"${sample%.*}".png
            fi
          done
        popd
      fi
    done
  popd 
done
