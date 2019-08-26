#!/bin/bash

#set -x
set -e

# Gets required version of synfig

MODE=$1 # references / results

VERSION="1.0.2" 
SYNFIG="synfig"

# For test results

THRESHOLD=5000
PASS=0
FAIL=0
FAILED_TEST=""

WORKDIR=$(cd `dirname "$0"`; pwd)

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
	TEST=$(compare -metric RMSE ${WORKDIR}/rendering/references/$NAME.png ${WORKDIR}/rendering/results/$NAME.png /dev/null 2>&1  || true)
	TEST=${TEST% *}
	TEST=${TEST%.*}
	echo "===$TEST==="
	if [ $TEST -lt $THRESHOLD ]; then
		echo "$NAME passed"
		PASS=$((PASS+1))
	else
		echo "$NAME failed"
		FAIL=$((FAIL+1))
		FAILED_TEST="$FAILED_TEST $NAME \n"
	fi
	echo "============================"
	echo
	echo
}

set-version () {
	FILE=$1

	pushd ${WORKDIR}
	# FILE="/home/reSHARMA/synfig-test-regressions/sources/layers/circle/circle-radius-0.txt"

	TEMP=${WORKDIR}
	FILE=${FILE##*$TEMP/} # TODO: do this in a better way 
	IFS='/'
	read -r -a array <<< "$FILE"
	unset IFS
	
	# array={rendering, sources, layers, circle, circle-radius-0.txt}
	
	size=${#array[@]}
	
	# size=5

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
	NAME=${FILE##*rendering/sources/} # TODO: do this in a better way
	DIR=${NAME%/*}	
	NAME=${NAME%.*}
	FILE=${FILE%.*}
	if [[ -f "${WORKDIR}/$FILE.sif" ]]; then
        if [ ! -d "${WORKDIR}/rendering/$MODE/$DIR" ]; then
            mkdir -p "${WORKDIR}/rendering/$MODE/$DIR"
            echo $DIR" created...."
        fi
		$SYNFIG -v 0 --time 0 -i "${WORKDIR}/$FILE.sif" -o "${WORKDIR}/rendering/$MODE/$NAME.png" >/dev/null
		if [ "$MODE" = "results" ]; then
			test-result $NAME
		fi
	fi
}

render-only-one-file () {
	FILE=$1
	set-version $FILE
	if [ "$MODE" = "references" ]; then
	get-synfig $VERSION
	fi
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
	render-dir "${WORKDIR}/$DIR"
}


if [ -z "$MODE" ]; then
	MODE="results"
fi

# Get the modified files from the commit 

cd "${WORKDIR}"
if [ -z "$TRAVIS_COMMIT_RANGE" ] || [ "$MODE" = "results" ]; then
   # rebuild everything
   CHANGED_FILES="rendering/sources/sources.txt"
else
   CHANGED_FILES=`git diff --name-only $TRAVIS_COMMIT_RANGE`
fi



for file in $CHANGED_FILES; do
	EXT=${file##*.}
	DIR=${file%/*}
	NAME=${file##*/}
	NAME=${NAME%.*}
	PARENT_DIR_NAME=${DIR##*/}
	TOP_DIR=${file%%/*}

	# eg: rendering/sources/layers/rectangle/rectangle-0.sif
	# EXT = "sif"
	# DIR = "rendering/sources/layers/rectangle"
	# NAME = "rectangle-0"
	# PARENT_DIR_NAME = "rectangle"
	# TOP_DIR = "rendering"
	
	if [ "$TOP_DIR" = "rendering" ]; then

		if [ "$EXT" = "sif" ]; then
			render-only-one-file $file
		elif [ "$EXT" = "txt" ]; then	
			if [ "$PARENT_DIR_NAME" = "$NAME" ]; then
				render-only-one-dir $file
			else	
				render-only-one-file "${WORKDIR}/$file"
			fi
		fi
	
	fi
done

if [ "$MODE" = "results" ]; then
echo
echo
echo "==================================="
echo "Failed tests: $FAIL"
echo "==================================="
echo "$FAILED_TEST"
echo "==================================="
echo
echo
if [ $FAIL -gt 0 ]; then
exit 1
fi
fi
