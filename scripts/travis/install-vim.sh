#!/bin/bash

set -ev

case "${TRAVIS_OS_NAME}" in
	linux)
		if [[ "${VIM_VERSION}" == "" ]]; then
			exit
		fi
		if [[ "${VIM_VERSION}" =~ ^nvim- ]]; then
			nvimver=${VIM_VERSION:5}
			wget -P "${HOME}/" "https://github.com/neovim/neovim/releases/download/${nvimver}/nvim.appimage"
			chmod u+x "${HOME}/nvim.appimage"
			mkdir -p "${HOME}/vim/bin"
			ln -fs "${HOME}/nvim.appimage" "${HOME}/vim/bin/vim"
		else
			git clone --depth 1 --branch "${VIM_VERSION}" https://github.com/vim/vim /tmp/vim
			cd /tmp/vim
			./configure --prefix="${HOME}/vim" --with-features=huge --enable-fail-if-missing
			make -j2
			make install
		fi
		;;
	osx)
		# Instead of --with-override-system-vim, manually link the executable because
		# it prevents MacVim installation with a bottle.
		ln -fs "$(brew --prefix macvim)/bin/mvim" "/usr/local/bin/vim"
		;;
	*)
		echo "Unknown value of \${TRAVIS_OS_NAME}: ${TRAVIS_OS_NAME}"
		exit 65
		;;
esac
