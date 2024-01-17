/*
 * Open In iTerm v1.3.2
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
			params.folderPath = ""
		}
		else if (ex.automationPermissionProblem) {
			displayAlert(ex.toString(), ex.details)
			return
		}
		else {
			displayAlert("Can't open folder in iTerm", ex.toString())
			return
		}
	}

	try {
		// if we want to open a new window, and iTerm is already running with open windows, 
		// "open -a" doesn't do what we want (it always opens a new tab in an existing window),
		// so we use iTerm's scripting API instead; it brings all iTerm windows to the front,
		// sadly, but I see no workaround
		if (!params.openTab && iTermIsRunning() && iTermHasOpenWindows(iTerm)) {
			iTerm.createWindowWithDefaultProfile()
			sendShellScript(iTerm, params.folderPath)
			return
		}

		// we also must use iTerm's scripting API if the path contains backslashes; otherwise,
		// the shell's working directory does not get changed, due to an apparent iTerm bug
		// (noticed in iTerm v3.4.8, still true in v3.4.23)
		if (params.folderPath.indexOf('\\') != -1) {
			if (!iTermIsRunning()) {
				iTerm.activate()  // opens a new window as iTerm starts up
				delay(1.0)        // give iTerm a little time to start up
			}
			else if (!iTermHasOpenWindows(iTerm) || !params.openTab) {
				iTerm.createWindowWithDefaultProfile()  // brings all iTerm windows to the front, sadly
			}
			else {
				// open a new tab in an existing iTerm window
				app.doShellScript("open -a iTerm")  // bring just one iTerm window to front, unminimized if needed
				iTerm.currentWindow.createTabWithDefaultProfile()
			}

			sendShellScript(iTerm, params.folderPath)
			return
		}
	}
	catch(ex) {
		if (ex.automationPermissionProblem)
			displayAlert(ex.toString(), ex.details)
		else
			displayAlert("Can't open folder in iTerm", ex.toString())
		return
	}

	// otherwise we don't need to script iTerm directly at all, "open -a" does what we need
	app.doShellScript("open -a iTerm " + quotedFormOf(params.folderPath))
}

// ----- utility functions -----

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

// Creates an Error object that represents a problem with access settings
// in System Settings > Privacy & Security > Automation.
//
function createAutomationPermissionError(summary, appName) {
	var err = new Error(summary)
	var details = "This can happen when Open In iTerm lacks access to control " + appName + "."

	if (systemVersion() >= 13) {
		details += " To check that, open System Settings > Privacy & Security > Automation," +
			" and ensure all the toggle switches for Open In iTerm are turned on."
	}
	else {
		details += " To check that, open System Preferences > Security & Privacy > Privacy > Automation," +
			" and ensure all the checkboxes for Open In iTerm are checked."
	}

	err.details = details
	err.automationPermissionProblem = true
	return err
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
	var finder, win, type

	try {
		finder = Application("Finder")
		if (!finder.finderWindows.length) return ""
		win = finder.finderWindows[0]
		type = win.target.class()
	}
	catch (ex) {
		// I've only ever seen the code above throw an error due to a permissions issue,
		// with an unhelpful error message that "Error: An error occurred"
		throw createAutomationPermissionError("Unable to examine the front Finder window", "Finder")
	}

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

// Determines whether or not iTerm has open windows.
// It'll start iTerm if it's not already running, so probably only call this after iTermIsRunning().
//
function iTermHasOpenWindows(iTerm) {
	try {
		return iTerm.windows.length > 0
	}
	catch (ex) {
		// the code above throws an error if Open In iTerm doesn't have access to control iTerm;
		// unfortunately the error is very generic ("Error: An error occurred"),
		// but I'm not aware of any other circumstances that make it throw, so just assume
		throw createAutomationPermissionError("Unable to call iTerm's AppleScript API", "iTerm")
	}
}

// Determines whether or not the iTerm application is already running.
//
function iTermIsRunning() {
	try {
		var iTermProcesses = Application("System Events").processes.whose({ name: { _equals: "iTerm2" }})
		return iTermProcesses.length > 0
	}
	catch (ex) {
		// the code above throws an error if Open In iTerm doesn't have access to control System Events;
		// unfortunately the error is very generic ("Error: An error occurred"),
		// but I'm not aware of any other circumstances that make it throw, so just assume
		throw createAutomationPermissionError("Unable to determine whether iTerm is running", "System Events")
	}
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

// Sends a change-directory shell script to the current iTerm window.
//
function sendShellScript(iTerm, folder) {
	if (folder == null || folder == "") return
	var shellScript = " cd " + quotedFormOf(folder) + " && clear && printf '\\e[3J'"

	// delay to let the iTerm window/tab we just opened become ready; if we don't do this,
	// we can get an "Error: Can't get object" error, or the shell script we send can just get displayed
	// in the iTerm window/tab above the first shell prompt, without actually getting executed,
	// or sometimes the shell script doesn't even get displayed but also doesn't execute;
	// in those latter two cases, retrying has no effect
	delay(0.5)

	try {
		iTerm.currentWindow.currentSession.write({ text: shellScript })
	}
	catch (ex) {
		if (ex && ex.message && ex.message.indexOf("An error occurred") != -1) {
			throw createAutomationPermissionError("Unable to call iTerm's AppleScript API", "iTerm")
		}
		else {
			// if this is "Error: Can't get object", that means iTerm wasn't done starting up
			// by the time we sent the shell script to it
			throw ex
		}
	}
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

// Returns the macOS major version number, or 9999 on failure.
//
function systemVersion() {
	var version = app.systemInfo().systemVersion

	if (version) {
		var parts = String(version).split(".")

		if (parts && parts.length) {
			var major = Number(parts[0])

			if (!isNaN(major) && major > 0) {
				return major
			}
		}
	}

	// assume the latest possible macOS version if we fail to get the true version
	return 9999
}
