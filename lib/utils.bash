#!/usr/bin/env bash

set -euo pipefail

GH_REPO="https://github.com/tree-sitter/tree-sitter"
TOOL_NAME="tree-sitter"
TOOL_TEST="tree-sitter --help"

fail() {
	echo -e "asdf-$TOOL_NAME: $*"
	exit 1
}

curl_opts=(-fsSL)

# NOTE: You might want to remove this if tree-sitter is not hosted on GitHub releases.
if [ -n "${GITHUB_API_TOKEN:-}" ]; then
	curl_opts=("${curl_opts[@]}" -H "Authorization: token $GITHUB_API_TOKEN")
fi

sort_versions() {
	sed 'h; s/[+-]/./g; s/.p\([[:digit:]]\)/.z\1/; s/$/.z/; G; s/\n/ /' |
		LC_ALL=C sort -t. -k 1,1 -k 2,2n -k 3,3n -k 4,4n -k 5,5n | awk '{print $2}'
}

list_github_tags() {
	git ls-remote --tags --refs "$GH_REPO" |
		grep -o 'refs/tags/.*' | cut -d/ -f3- |
		sed 's/^v//'
}

list_all_versions() {
	list_github_tags
}

download_release() {
	local version filename url platform arch
	version="$1"
	filename="$2"
	case "$(uname -s)" in
	Linux)
		platform=linux
		;;
	Darwin)
		local major minor
		major=$(echo "$version" | cut -d. -f1)
		minor=$(echo "$version" | cut -d. -f2)
		if [ "$version" == "0.18.0" ] || [ "$major" == "0" ] && [ "$minor" -lt "18" ]; then
			platform=osx
		else
			platform=macos
		fi
		;;
	*)
		fail "Platform not supported $(uname -s)"
		;;
	esac
	case "$(uname -m)" in
	x86_64)
		arch=x64
		;;
	i686)
		arch=x86
		;;
	*)
		arch="$(uname -m)"
		;;
	esac

	url="$GH_REPO/releases/download/v$version/tree-sitter-$platform-$arch.gz"

	echo "* Downloading $TOOL_NAME release $version..."
	echo curl "${curl_opts[@]}" -o "$filename" -C - "$url" || fail "Could not download $url"
	curl "${curl_opts[@]}" -o "$filename" -C - "$url" || fail "Could not download $url"
}

install_version() {
	local install_type="$1"
	local version="$2"
	local install_path="${3%/bin}/bin"

	if [ "$install_type" != "version" ]; then
		fail "asdf-$TOOL_NAME supports release installs only"
	fi

	(
		mkdir -p "$install_path"
		cp "$ASDF_DOWNLOAD_PATH/tree-sitter-$version" "$install_path/tree-sitter"
		chmod +x "$install_path/tree-sitter"

		local tool_cmd
		tool_cmd="$(echo "$TOOL_TEST" | cut -d' ' -f1)"
		test -x "$install_path/$tool_cmd" || fail "Expected $install_path/$tool_cmd to be executable."

		echo "$TOOL_NAME $version installation was successful!"
	) || (
		rm -rf "$install_path"
		fail "An error occurred while installing $TOOL_NAME $version."
	)
}
