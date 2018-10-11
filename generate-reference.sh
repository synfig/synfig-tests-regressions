#!/bin/bash

set -x

# Gets required version of synfig

#TRAVIS_COMMIT_RANGE="88050ae37f95...bd64d25af949"
#TRAVIS_BUILD_DIR="/home/reshabh/synfig-tests-regressions"

$SYNFIG=""

get-synfig-tar () {
SYNFIG="/tmp/synfig-$VERSION/synfig"
if [ ! -d "/tmp/synfig-$VERSION" ]; then
	wget --quiet "https://sourceforge.net/projects/synfig/files/releases/$VERSION/linux/synfigstudio-$VERSION.x86_64.tar.bz2/download" -O "/tmp/synfig-$VERSION.tar.bz2"
	mkdir -p /tmp/synfig-$VERSION
	tar jxf /tmp/synfig-$VERSION.tar.bz2 -C /tmp/synfig-$VERSION --strip-components=1
fi
}

get-synfig-appimage () {
SYNFIG="/tmp/synfig-$VERSION.appimage --appimage-exec synfig" 
if [ ! -d "/tmp/synfig-$VERSION.appimage" ]; then
	if [ "$#" -eq 3 ]; then
		LINK=$3
	else
		LINK="https://sourceforge.net/projects/synfig/files/releases/$VERSION/linux/synfigstudio-$2.appimage/download"
	fi
	wget --quiet $LINK -O "/tmp/synfig-$VERSION.appimage"
	chmod +x /tmp/synfig-$VERSION.appimage
fi
}

get-synfig () {
VERSION=$1
PARSED_VERSION=${VERSION//./}

if [ $PARSED_VERSION -lt 120 ]; then
	get-synfig-tar $VERSION
elif [ $PARSED_VERSION -eq 120 ]; then
	get-synfig-appimage $VERSION "1.2.0-64bit-r2"
elif [ $PARSED_VERSION -eq 121 ]; then
	get-synfig-appimage $VERSION "1.2.1-64bit"
elif [ $PARSED_VERSION -eq 122 ]; then
	get-synfig-appimage $VERSION "18.09.14-linux64-286f1" "https://sourceforge.net/projects/synfig/files/releases/1.2.2/SynfigStudio-1.2.2-18.09.14-linux64-286f1.appimage/download"
fi
}

# if default version is changed force generate all reference
# if particular layer reference is changed generate it's reference
# if some files are added generate references for them

# Get the modified files from the commit 

CHANGED_FILES=`git diff --name-only $TRAVIS_COMMIT_RANGE`

for file in $CHANGED_FILES; do

	EXT=${file##*.}
	DIR=${file%/*}
	NAME=${file##*/}
	NAME=${NAME%.*}

	if [ "$EXT" = "txt" ]; then
		if [ "$NAME" = "default-version" ]; then
			# run force generate png
			bash sources/force-render-png.sh
		else
			# just run for one dir
			pushd $DIR
			VERSION=`cat $NAME.txt`
			get-synfig $VERSION
			mkdir -p ${TRAVIS_BUILD_DIR}/$DIR/../../../references/${DIR#*/}
			for sample in * ; do
				if [ "${sample##*.}" = "sif" ]; then
					if [ -f "${TRAVIS_BUILD_DIR}/$DIR/$sample" ]; then
						$SYNFIG -v 10 --time 0 -i "${TRAVIS_BUILD_DIR}/$DIR/$sample" -o ${TRAVIS_BUILD_DIR}/$DIR/../../../references/${DIR#*/}/${sample%.*}.png
					fi
				fi
			done
			popd
		fi
	elif [ "$EXT" = "sif" ]; then
		PARENT_DIR=${DIR##*/}
		pushd $DIR
		if [ -f $NAME.txt ]; then
			VERSION=`cat $NAME.txt`
		else
			VERSION=`cat "${TRAVIS_BUILD_DIR}/sources/default-version.txt"`
		fi
		get-synfig $VERSION
		mkdir -p ${TRAVIS_BUILD_DIR}/$DIR/../../../references/${DIR#*/}
		if [ -f "${TRAVIS_BUILD_DIR}/$file" ]; then
			$SYNFIG -v 10 --time 0 -i ${TRAVIS_BUILD_DIR}/$file -o ${TRAVIS_BUILD_DIR}/$DIR/../../../references/${DIR#*/}/$NAME.png
		fi
		popd
	fi
done
