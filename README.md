<p align="center">
  <img src="Screenshots/App-Icon.png" alt="Open In iTerm Icon"/>
</p>

It's often handy to switch between looking at a folder's contents graphically, and running command-line utilities in it. You can switch from command-line mode to graphical mode by running `open .` to view your shell's current working directory in Finder, but there is no built-in utility to do the reverse.

That's why this app exists. After installing it as a Finder toolbar button, you can click the icon in (just about) any Finder window to open a new [iTerm](https://iterm2.com) tab, with your shell's working directory automatically switched Finder's current folder. Or you can hold the **fn** key down as you click, to open the folder in a new iTerm window, instead of a new tab.

If you prefer Apple's Terminal app, see [Open in Terminal](https://github.com/jakshin/open-in-terminal).

## Usage

Once the app is installed, each of your Finder windows will contain the its icon. Just click it to load the Finder window's (or tab's) folder in a new iTerm tab (or window). You can also launch the application in other ways, such as through Spotlight, and it will use the folder displayed in your frontmost Finder window.

A small wrapper script named `iterm` is also provided, which invokes the app to open a new iTerm tab or window displaying a given directory. This can be handy if you use both Terminal and iTerm. Run `iterm --help` for usage details.


## Installation


### Step 1: Download the files

Either click GitHub's **Clone or download > Download ZIP** button above to download open-in-iterm-master.zip, unzip it, and drag the resulting folder to somewhere convenient, such as `~/AppleScripts`; or clone with Git:

```bash
git clone https://github.com/jakshin/open-in-iterm.git
```


### Step 2: Build the application

Open the folder which contains `Open In iTerm.applescript`, and run the following command at a prompt:

```bash
./build.sh
```

This will create `Open In iTerm.app`.

A command-line utility named `modifier-keys` is incorporated into the application's bundle. The application uses it to determine which modifier keys are pressed as it is launched. The compiled binary is included in Git; if you'd like to recompile it from its C source yourself, you'll need to [install Xcode's command-line tools](https://developer.apple.com/library/ios/technotes/tn2339/_index.html), then run `make` in the `modifier-keys` folder.


### Step 3: Drag the application into your Finder toolbar

Hold the **command** key down and drag `Open In iTerm.app` into your Finder toolbar:

![[screenshot]](Screenshots/Drag-Icon.png)


### Step 4: Install the command-line utility (optional)

Move or symlink the `iterm` utility to somewhere that's in your shell's path, or add the directory it's in to your path. For example, to create a symlink in `/usr/local/bin`, run this from the directory containing the utility:

```bash
sudo ln -s "`pwd -P`/iterm" /usr/local/bin/iterm
```


## Uninstallation

To uninstall the app, hold the **command** key down and drag its icon out of your Finder toolbar, then delete it.

If you installed the command-line `iterm` utility, delete it and any symlinks to it.
