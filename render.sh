#!/bin/bash

#set -x

# Gets required version of synfig

MODE=$1 # references / results

VERSION="1.0.2" 
SYNFIG=""

# For test results

THRESHOLD=5000
PASS=0
FAIL=0
FAILED_TEST=""

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
	if [ ! -e "/tmp/synfig-$VERSION.appimage" ]; then
		if [ "$#" -eq 3 ]; then
			LINK=$3
		else
			LINK="https://sourceforge.net/projects/synfig/files/releases/$VERSION/linux/synfigstudio-$2.appimage/download"
		fi
		wget --quiet --no-check-certificate $LINK -O "/tmp/synfig-$VERSION.appimage"
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
	elif [ $PARSED_VERSION -eq 131020181101 ]; then
		get-synfig-appimage $VERSION "1.3.10.2018.11.01" "https://dev.icystar.com/downloads/SynfigStudio-1.3.10-testing-18.11.01-linux64-28c73.appimage"
	fi
}

# if default version is changed force generate all reference
# if particular layer reference is changed generate it's reference
# if some files are added generate references for them

test-result () {
	NAME=$1
	TEST=$(compare -metric RMSE $TRAVIS_BUILD_DIR/references/$NAME.png $TRAVIS_BUILD_DIR/results/$NAME.png NULL 2>&1)
	TEST=${TEST% *}
	TEST=${TEST%.*}
	if [ $TEST -lt $THRESHOLD ]; then
		echo "$NAME passed"
		PASS=$((PASS+1))
	else
		echo "SNAME failed"
		FAIL=$((FAIL+1))
		FAILED_TEST="$FAILED_TEST $NAME \n"
	fi
}

set-version () {
	FILE=$1

	pushd $TRAVIS_BUILD_DIR
	# FILE="/home/reSHARMA/synfig-test-regressions/sources/layers/circle/circle-radius-0.txt"

	TEMP=$TRAVIS_BUILD_DIR
	FILE=${FILE##*$TEMP/} # TODO: do this in a better way 
	IFS='/'
	read -r -a array <<< "$FILE"
	unset IFS
	
	# array={sources, layers, circle, circle-radius-0.txt}
	
	size=${#array[@]}
	
	# size=4

	array[$size - 1]=${array[$size - 1]%.*}

	# array={sources, layers, circle, circle-radius-0}

	NAME=${array[$size - 1]}
	unset "array[$size - 1]"
	for element in "${array[@]}"
	do
		cd $element && \
		if [ -f "$element.txt" ]; then
			VERSION=`cat $element.txt`
		fi
	done && \
	if [ -f "$NAME.txt" ]; then
		VERSION=`cat $NAME.txt`
	fi
	for element in "${array[@]}"
	do
		cd ../
	done
	popd
}

synfig-render () {
	FILE=$1
	NAME=${FILE##*sources/} # TODO: do this in a better way 
	NAME=${NAME%.*}
	FILE=${FILE%.*}
	if [[ -f "${TRAVIS_BUILD_DIR}/$FILE.sif" ]]; then
		$SYNFIG -v 10 --time 0 -i "${TRAVIS_BUILD_DIR}/$FILE.sif" -o "${TRAVIS_BUILD_DIR}/sources/../$MODE/$NAME.png"
		if [ "$MODE" = "results" ]; then
			test-result $NAME
		fi
	fi
}

render-only-one-file () {
	FILE=$1
	set-version $FILE
	get-synfig $VERSION
	synfig-render $FILE
}

render-dir () {
	DIR=$1
	cd $DIR && \
	for file in *; do
		if [[ -e $1/$file ]]; then
			if [[ -f $1/$file ]]; then
				pwd
				render-only-one-file "$1/$file"
			else
				render-dir "$1/$file"
			fi
		fi
	done
}

render-only-one-dir () {
	FILE=$1
	DIR=${FILE%/*}
	render-dir "$TRAVIS_BUILD_DIR/$DIR"
}

# Get the modified files from the commit 

CHANGED_FILES=`git diff --name-only $TRAVIS_COMMIT_RANGE`

for file in $CHANGED_FILES; do
	EXT=${file##*.}
	DIR=${file%/*}
	NAME=${file##*/}
	NAME=${NAME%.*}

	# eg: sources/layers/rectangle/rectangle-0.sif
	# EXT = "sif"
	# DIR = "sources/layers/rectangle"
	# NAME = "rectangle-0"

	if [ $(echo $NAME | grep -i '-') ]; then
		# just a single file is changed be it .txt or .sif
		render-only-one-file "$TRAVIS_BUILD_DIR/$file"
	else
		# we need to render a whole directory
		render-only-one-dir $file
	fi
done
