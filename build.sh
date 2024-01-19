#!/bin/bash -e
# Builds the "Open In iTerm" Finder-toolbar script as an application.

app_name="Open In iTerm"
script_name="$app_name.applescript"
bundle_name="$app_name.app"
bundle_id="com.apple.ScriptEditor.id.${app_name// }"

function usage() {
	script_name="$(basename "$0")"
	echo "Builds the \"$app_name\" Finder toolbar script as an application."
	echo 'See README.md for installation instructions.'
	echo
	echo "Usage: $script_name [options]"
	echo
	echo "By default, a light or dark icon is chosen automatically, based on"
	echo "macOS's current setting. Pass --light or --dark to override."
	exit 1
}

unset appearance

for arg; do
	if [[ $arg == "--dark" ]]; then
		appearance="dark"
	elif [[ $arg == "--light" ]]; then
		appearance="light"
	else  # anything else, including -h/--help
		usage
	fi
done

if [[ -z $appearance ]]; then
	if dark="$(osascript -e 'tell application "System Events" to tell appearance preferences to log dark mode is true' 2>&1)"; then
		[[ $dark == true ]] && appearance="dark" || appearance="light"
	else
		echo "Could not detect whether dark mode is enabled, due to this error:"
		echo " ${dark//*execution error:/}"
		echo -e "\nThe application will be built with an icon for light mode, by default."
		echo -e "Pass the --light or --dark option to select an icon manually.\n"
		appearance="light"
	fi
fi

os_version="$(sw_vers -productVersion)"
os_version="${os_version/.*/}"  # Major version only

icon="macOS-$os_version-$appearance"

if [[ ! -f "icon/$icon.icns" ]] && (( os_version > 11 )); then
	icon="macOS-11-$appearance"
fi


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


# --- Build Logic ---

# run from the path in which the build script resides
cd -- "$(dirname "$0")"

# find some info in the script
version="$(head -n 5 "$script_name" | grep -Eo "[0-9.]{3,}" || true)"
copyright="$(head -n 20 "$script_name" | grep -E "^[* ]+Copyright" || true)"

if [[ -z $version || -z $copyright ]]; then
	echo "Unable to determine bundle version and/or copyright, aborting"
	exit 1
fi

while [[ ${copyright:0:1} == " " || ${copyright:0:1} == "*" ]]; do
	copyright="${copyright:1}"
done

# remove any existing version of the app bundle, and create a new one
rm -rf "$bundle_name"
osacompile -l JavaScript -o "$bundle_name" "$script_name"
echo "Compiled $script_name -> $bundle_name"

# copy resources into the bundle
cp "icon/$icon.icns" "$bundle_name/Contents/Resources/applet.icns"
cp modifier-keys/modifier-keys "$bundle_name/Contents/Resources"
xattr -c "$bundle_name/Contents/Resources/applet.icns" "$bundle_name/Contents/Resources"

# fix up Info.plist
info_plist="$(absolute_path "$bundle_name/Contents/Info.plist")"

defaults write "$info_plist" CFBundleIdentifier "$bundle_id"
defaults write "$info_plist" CFBundleShortVersionString "$version"
defaults write "$info_plist" CFBundleVersion "$version"
defaults write "$info_plist" LSUIElement 1
defaults write "$info_plist" NSHumanReadableCopyright "'$copyright'"

plutil -convert xml1 "$info_plist"
chmod 644 "$info_plist"

# sign the app when running on Big Sur, or it won't work
if (( os_version >= 11 )); then
	codesign --force --sign - "$bundle_name"
fi

# success!
echo Done
