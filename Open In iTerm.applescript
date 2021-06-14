/*
 * Open In iTerm v1.2
 *
 * This is a Finder-toolbar script, which opens iTerm tabs/windows conveniently.
 * When its icon is clicked on in the toolbar of a Finder window, it opens a new iTerm tab,
 * or window if the fn key is down, and switches the shell's current working directory
 * to the Finder window's folder. See README.md for more details, including how to build
 * and install.
 *
 * Copyright (c) 2018, 2021 Jason Jackson
 *
 * This program is free software: you can redistribute it and/or modify it under the terms
 * of the GNU General Public License as published by the Free Software Foundation,
 * either version 3 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
 * without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with this program.
 * If not, see <http://www.gnu.org/licenses/>.
 */

ObjC.import('Foundation')

var app = Application.currentApplication()
app.includeStandardAdditions = true

function run() {
	var iTerm, params = {}

	try {
		iTerm = Application("iTerm")
	}
	catch (ex) {
		displayAlert("iTerm isn't installed", ex.toString())
		return
	}

	// figure out what to do, based on command-line parameters, keyboard state and/or Finder state
	parseCommandLineParameters(collectCommandLineParameters(), params)

	if (params.openTab == undefined) {
		params.openTab = shouldOpenTabThisTime()
		
		if (params.openTab === null) {
			// the option key is down, and the Finder window will close, so we should do nothing
			return
		}
	}

	try {
		if (params.folderPath == undefined) {
			params.folderPath = getFinderFolder()
		}
	}
	catch (ex) {
		if (ex.noFolderFound) {
			var details = "Finder can display some things that look like folders, but for which there is no actual on-disk folder; "
			details += "since there's no actual \"" + ex.message + "\" folder, it can't be opened in iTerm.\n"

			var reply = displayAlert("Can't open folder in iTerm", details, [ "Cancel", "Open iTerm Anyway" ])
			if (reply.buttonReturned == "Cancel") return
		}
		else {
			displayAlert("Can't open folder in iTerm", ex.toString())
			return
		}
	}

	// get iTerm into the desired state
	if (!iTermIsRunning()) {
		iTerm.activate()  // opens a new window as iTerm starts up
	}
	else if (!iTerm.windows.length || !params.openTab) {
		iTerm.createWindowWithDefaultProfile()  // brings all iTerm windows to the front, sadly
	}
	else {
		// open a new tab in an existing iTerm window
		activateFrontWindow("iTerm")   // bring just one iTerm window to the front
		var win = iTerm.currentWindow  // will be unminimized if needed
		win.createTabWithDefaultProfile()
	}

	// send our shell script to iTerm's window
	var shellScript = buildShellScript(params.folderPath)
	if (shellScript) {
		// loop until iTerm is ready, in case it's just starting up
		for (var attempt = 0; attempt < 100; attempt++) {
			try {
				iTerm.currentWindow.currentSession.write({ text: shellScript })
				break
			}
			catch (ex) {
				// wait just a bit before trying again
				delay(0.1)
			}
		}

		// give up after 10 seconds
		if (attempt >= 100) return

		// no need to send a keystroke to clear the scrollback buffer here anymore;
		// instead, we print an escape sequence that does so in our shell script,
		// so we don't need special permissions associated with sending keystrokes
		// delay(0.2)
		// Application("System Events").keystroke("K", { using: [ "command down", "shift down" ] })
	}
}

// ----- utility functions -----

// "Activates" just the frontmost window of an application, so that it becomes the active application,
// and its frontmost window is the front window on the screen, but its other windows remain in the background.
//
function activateFrontWindow(appName) {
	app.doShellScript("open -a " + quotedFormOf(appName))
}

// Builds a shell script which will change the working directory to the passed folder, then clear the screen.
// Returns an empty string if no folder is passed.
//
function buildShellScript(folder) {
	if (folder == null || folder == "") return ""
	return " cd " + quotedFormOf(folder) + " && clear && printf '\\e[3J'"
}

// Collects any command-line parameters passed to the application, returning them as an array;
// giving run() an 'argv' parameter doesn't seem to work, for whatever reason (on macOS Sierra 10.12.6).
//
function collectCommandLineParameters() {
	// see https://github.com/JXA-Cookbook/JXA-Cookbook/wiki/Shell-and-CLI-Interactions
	var argv = []
	var args = $.NSProcessInfo.processInfo.arguments  // NSArray

	for (var i = 0; i < args.count; i++) {
		argv.push(ObjC.unwrap(args.objectAtIndex(i)))
	}

	return argv
}

// Displays an alert dialog.
// The 'buttons' parameter is optional, and defaults to one OK button.
//
function displayAlert(title, details, buttons) {
	if (!buttons) buttons = ["OK"]
	return app.displayAlert(title, { message: details, as: "critical", buttons: buttons })
}

// Gets the folder being displayed in Finder's frontmost window.
// Returns an empty string if there are no Finder windows (including minimized, full-screen, or in another space);
// throws an exception if the frontmost Finder window isn't displaying an actual on-disk folder.
//
function getFinderFolder() {
	var finder = Application("Finder")

	if (!finder.finderWindows.length) return ""
	var win = finder.finderWindows[0]
	var type = win.target.class()

	try {
		if (type == "computer-object") {
			return "/Volumes"  // closest analogue for "this computer"
		}

		// see https://stackoverflow.com/questions/45426227/get-posix-path-of-active-finder-window-with-jxa-applescript
		return $.NSURL.alloc.initWithString(win.target.url()).fileSystemRepresentation
	}
	catch (ex) {
		if (type == "trash-object" || (type == "folder" && win.name() == "Trash")) {
			// items shown by Finder in the Trash can come from various places (e.g. mounted drives, iCloud Drive),
			// so we'll just use whatever macOS says is "the path to Trash" (always ~/.Trash as far as I can tell)
			return app.pathTo("trash", { as: "alias", folderCreation: false }).toString()
		}

		var err = new Error(win.name())
		err.noFolderFound = true
		throw err
	}
}

// Gets the full path to our modifier-keys helper program.
//
function getPathToCheckModifierKeys() {
	var pathToMe = app.pathTo(this, { as: "alias" }).toString()
	
	if (pathToMe.endsWith(".app/")) pathToMe = pathToMe.slice(0, -1)
	if (pathToMe.endsWith(".app")) {
		return pathToMe + "/Contents/Resources/modifier-keys"
	}

	// assume we're running in Script Editor
	var lastSlash = pathToMe.lastIndexOf('/')
	return pathToMe.substring(0, lastSlash) + "/modifier-keys/modifier-keys"
}

// Determines whether or not the iTerm application is already running.
//
function iTermIsRunning() {
	var iTermProcesses = Application("System Events").processes.whose({ name: { _equals: "iTerm2" }})
	return iTermProcesses.length > 0
}

// Parses command-line parameters into the given 'params' object (setting 'openTab' and/or 'folderPath'),
// ignoring any invalid options, and keeping the last value for conflicting options or folderPath.
//
function parseCommandLineParameters(argv, params) {
	var endOfOptions = false

	for (var i = 1; i < argv.length; i++) {
		var arg = argv[i].trim()
		if (arg == "") continue

		if (arg == "--") {
			endOfOptions = true
			continue
		}

		if (!endOfOptions && (arg == "-t" || arg == "--tab")) {
			params.openTab = true
		}
		else if (!endOfOptions && (arg == "-w" || arg == "--window")) {
			params.openTab = false
		}
		else {
			params.folderPath = arg
		}
	}
}

// Returns the quoted form of a string, like AppleScript's "quoted form of".
// From https://stackoverflow.com/questions/28044758/calling-shell-script-with-javascript-for-automation
//
function quotedFormOf(str) {
	return "'" + str.replace(/'/g, "'\\''") + "'"
}

// Detects whether the fn modifier key is down, and decides whether we should open a new iTerm tab this time
// (as opposed to a new iTerm window).
//
function shouldOpenTabThisTime() {
	var pathToCheckModifierKeys = getPathToCheckModifierKeys()
	var modifierKeys = app.doShellScript(quotedFormOf(pathToCheckModifierKeys))
	
	if (modifierKeys.indexOf("option") != -1) {
		return null  // request early exit
	}

	// open a tab unless the fn or shift key is down
	return (modifierKeys.indexOf("fn") == -1 && modifierKeys.indexOf("shift") == -1)
}
