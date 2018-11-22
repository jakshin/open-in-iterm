#!/bin/bash -e
# Builds the "Open In iTerm" Finder-toolbar script as an application.

script_name="Open In iTerm.applescript"
bundle_name="Open In iTerm.app"
bundle_id="com.apple.ScriptEditor.id.OpenIniTerm"
version="1.0"
copyright="Copyright © 2018 Jason Jackson"

# --- Utilities ---

function absolute_path() {
	# prints a file's absolute path, given a relative path to it.
	# note that the file must exist.

	if [[ ! -f "$1" ]]; then
		return 1
	fi

	if [[ $1 == */* ]]; then
		echo "$(cd "${1%/*}"; pwd)/${1##*/}"
	else
		echo "$(pwd)/$1"
	fi
}

# --- Options ---

function usage() {
	script_name="`basename "$0"`"
	echo 'Builds the "Open In iTerm" Finder-toolbar script as an application.'
	echo 'See README.md for installation instructions.'
	echo
	echo -e "Usage: $script_name [options]\n"
	echo "Options:"
	echo "  --dark   Use a dark icon suitable for macOS Mojave's dark mode"
	echo "  --light  Use a light icon for Mojave's light mode, and earlier macOS versions"
	exit 1
}

icon="light.icns"

for arg in "$@"; do
	if [[ $arg == "--dark" ]]; then
		icon="dark.icns"
	elif [[ $arg == "--light" ]]; then
		icon="light.icns"
	else  # anything else, including -h/--help
		usage
	fi
done

# --- Build Logic ---

# run from the path in which the build script resides
cd -- "`dirname "$0"`"

# remove any existing version of the app bundle, and create a new one
rm -rf "$bundle_name"
osacompile -l JavaScript -o "$bundle_name" "$script_name"

# copy resources into the bundle
cp "icon/$icon" "$bundle_name/Contents/Resources/applet.icns"
cp modifier-keys/modifier-keys "$bundle_name/Contents/Resources"

# fix up Info.plist
info_plist="$(absolute_path "$bundle_name/Contents/Info.plist")"

defaults write "$info_plist" CFBundleIdentifier "$bundle_id"
defaults write "$info_plist" CFBundleShortVersionString "$version"
defaults write "$info_plist" CFBundleVersion "$version"
defaults write "$info_plist" LSUIElement 1
defaults write "$info_plist" NSHumanReadableCopyright "$copyright"

plutil -convert xml1 "$info_plist"
chmod 644 "$info_plist"

# success!
echo Done
