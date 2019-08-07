#!/bin/bash

set -ev

case "${TRAVIS_OS_NAME}" in
	linux)
		wget "https://julialang-s3.julialang.org/bin/linux/x64/${JULIA_VERSION%.*}/julia-${JULIA_VERSION}-linux-x86_64.tar.gz"
		tar xvf "julia-${JULIA_VERSION}-linux-x86_64.tar.gz" -C $HOME
		mv "${HOME}/julia-${JULIA_VERSION}" "${HOME}/julia"
		;;
	osx)
		wget https://julialang-s3.julialang.org/bin/mac/x64/${JULIA_VERSION%.*}/julia-${JULIA_VERSION}-mac64.dmg
		sudo hdiutil attach "julia-${JULIA_VERSION}-mac64.dmg"
		ln -s "/Volumes/julia-${JULIA_VERSION}/julia-${JULIA_VERSION%.*}.app/Contents/Resources/julia" $HOME/julia
		;;
	*)
		echo "Unknown value of \${TRAVIS_OS_NAME}: ${TRAVIS_OS_NAME}"
		exit 65
		;;
esac
