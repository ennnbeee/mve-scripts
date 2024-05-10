#!/bin/bash
#set -x

###########################################
##
## Script to install an App using AutoBrew
##
###########################################

# Define variables
brewApp="skype" # Brew App to be installed
currentRelease=$(curl --silent "https://api.github.com/repos/Homebrew/brew/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

# Generated variables
brewweburl="https://github.com/Homebrew/brew/releases/download/$currentRelease/Homebrew-$currentRelease.pkg"
logandmetadir="/Library/Logs/Microsoft/Intune/Scripts/AutoBrew" # The location of our logs
tempdir=$(mktemp -d)
log="$logandmetadir/$brewApp.log" # The location of the script log file

# Functions
## Function to download the app files
function downloadApp() {

    #################################################################################################################
    #################################################################################################################
    ##
    ##  This function takes the following global variables and downloads the URL provided to a temporary location
    ##
    ##  Functions
    ##
    ##      waitForCurl (Pauses download until all other instances of Curl have finished)
    ##      downloadSize (Generates human readable size of the download for the logs)
    ##
    ##  Variables
    ##
    ##      $appname = Description of the App we are installing
    ##      $brewweburl = URL of download location
    ##      $tempfile = location of temporary DMG file downloaded
    ##
    ###############################################################
    ###############################################################

    echo "$(date) | Starting downlading of [$appname]"

    # wait for other downloads to complete
    waitForProcess "curl -f"

    #download the file
    echo "$(date) | Downloading $appname"

    cd "$tempdir"
    curl -f -s --connect-timeout 30 --retry 5 --retry-delay 60 -L -J -O "$brewweburl"
    if [ $? == 0 ]; then

        # We have downloaded a file, we need to know what the file is called and what type of file it is
        tempSearchPath="$tempdir/*"
        for f in $tempSearchPath; do
            tempfile=$f
        done

        case $tempfile in

        *.pkg | *.PKG)
            packageType="PKG"
            ;;

        *.zip | *.ZIP)
            packageType="ZIP"
            ;;

        *.dmg | *.DMG)
            packageType="DMG"
            ;;

        *)
            # We can't tell what this is by the file name, lets look at the metadata
            echo "$(date) | Unknown file type [$f], analysing metadata"
            metadata=$(file "$tempfile")
            if [[ "$metadata" == *"Zip archive data"* ]]; then
                packageType="ZIP"
                mv "$tempfile" "$tempdir/install.zip"
                tempfile="$tempdir/install.zip"
            fi

            if [[ "$metadata" == *"xar archive"* ]]; then
                packageType="PKG"
                mv "$tempfile" "$tempdir/install.pkg"
                tempfile="$tempdir/install.pkg"
            fi

            if [[ "$metadata" == *"bzip2 compressed data"* ]] || [[ "$metadata" == *"zlib compressed data"* ]]; then
                packageType="DMG"
                mv "$tempfile" "$tempdir/install.dmg"
                tempfile="$tempdir/install.dmg"
            fi

            ;;
        esac

        if [[ ! $packageType ]]; then
            echo "Failed to determine temp file type [$metadata]"
            rm -rf "$tempdir"
        else
            echo "$(date) | Downloaded [$app] to [$tempfile]"
            echo "$(date) | Detected install type as [$packageType]"
        fi

    else

        echo "$(date) | Failure to download [$brewweburl] to [$tempfile]"
        exit 1
    fi

}

## Function to check if we need to update or not
function updateCheck() {

    #################################################################################################################
    #################################################################################################################
    ##
    ##  This function takes the following dependencies and variables and exits if no update is required
    ##
    ##  Functions
    ##
    ##      fetchLastModifiedDate
    ##
    ##  Variables
    ##
    ##      $appname = Description of the App we are installing
    ##      $tempfile = location of temporary DMG file downloaded
    ##      $volume = name of volume mount point
    ##      $app = name of Application directory under /Applications
    ##
    ###############################################################
    ###############################################################

    echo "$(date) | Checking if we need to install or update [$appname]"

    ## Is the app already installed?
    if [ -d "/Applications/$app" ]; then

        # App is installed, if it's updates are handled by MAU we should quietly exit
        if [[ $autoUpdate == "true" ]]; then
            echo "$(date) | [$appname] is already installed and handles updates itself, exiting"
            exit 0
        fi

        # App is already installed, we need to determine if it requires updating or not
        echo "$(date) | [$appname] already installed, let's see if we need to update"
        fetchLastModifiedDate

        ## Did we store the last modified date last time we installed/updated?
        if [[ -d "$logandmetadir" ]]; then

            if [ -f "$metafile" ]; then
                previouslastmodifieddate=$(cat "$metafile")
                if [[ "$previouslastmodifieddate" != "$lastmodified" ]]; then
                    echo "$(date) | Update found, previous [$previouslastmodifieddate] and current [$lastmodified]"
                    update="update"
                else
                    echo "$(date) | No update between previous [$previouslastmodifieddate] and current [$lastmodified]"
                    echo "$(date) | Exiting, nothing to do"
                    exit 0
                fi
            else
                echo "$(date) | Meta file [$metafile] not found"
                echo "$(date) | Unable to determine if update required, updating [$appname] anyway"

            fi

        fi

    else
        echo "$(date) | [$appname] not installed, need to download and install"
    fi

}

## Install Brew Function
function installBrew() {

    #################################################################################################################
    #################################################################################################################
    ##
    ##  This function takes the following global variables and installs the PKG file
    ##
    ##  Functions
    ##
    ##      fetchLastModifiedDate (Called with update flag which causes the function to write the new lastmodified date to the metadata file)
    ##
    ##  Variables
    ##
    ##      $tempfile = location of temporary DMG file downloaded
    ##      $volume = name of volume mount point
    ##      $app = name of Application directory under /Applications
    ##
    ###############################################################
    ###############################################################

    cd /opt
    echo "$(date) | Installing Brew"
    if [[ $(uname -m) == 'arm64' ]]; then
        # Apple Silicon
        brewPath="/opt/homebrew/bin/brew"
    else
        # Intel
        brewPath="/usr/local/Homebrew/bin/brew"
    fi

    $brewPath --version
    if [[ $? != 0 ]]; then
        downloadApp
        # Install Homebrew
        installer -pkg "$tempfile" -target /Applications
        # Checking if the app was installed successfully
        if [ "$?" = "0" ]; then

            echo "$(date) | Brew Installed"
            echo "$(date) | Cleaning Up"
            rm -rf "$tempdir"

            echo "$(date) | Application Brew succesfully installed"
            fetchLastModifiedDate update
        else
            echo "$(date) | Failed to install Brew"
            rm -rf "$tempdir"
            exit 1
        fi
    else
        echo "$(date) | Brew Updating"
        $brewPath update
    fi

}

## function to delay script if the specified process is running
waitForProcess() {

    #################################################################################################################
    #################################################################################################################
    ##
    ##  Function to pause while a specified process is running
    ##
    ##  Functions used
    ##
    ##      None
    ##
    ##  Variables used
    ##
    ##      $1 = name of process to check for
    ##      $2 = length of delay (if missing, function to generate random delay between 10 and 60s)
    ##      $3 = true/false if = "true" terminate process, if "false" wait for it to close
    ##
    ###############################################################
    ###############################################################

    processName=$1
    fixedDelay=$2
    terminate=$3

    echo "$(date) | Waiting for other [$processName] processes to end"
    while ps aux | grep "$processName" | grep -v grep &>/dev/null; do

        if [[ $terminate == "true" ]]; then
            echo "$(date) | + [$appname] running, terminating [$processpath]..."
            pkill -f "$processName"
            return
        fi

        # If we've been passed a delay we should use it, otherwise we'll create a random delay each run
        if [[ ! $fixedDelay ]]; then
            delay=$(($RANDOM % 50 + 10))
        else
            delay=$fixedDelay
        fi

        echo "$(date) |  + Another instance of $processName is running, waiting [$delay] seconds"
        sleep $delay
    done

    echo "$(date) | No instances of [$processName] found, safe to proceed"

}

## Function to delay until the user has finished setup assistant.
waitForDesktop() {
    until ps aux | grep /System/Library/CoreServices/Dock.app/Contents/MacOS/Dock | grep -v grep &>/dev/null; do
        delay=$(($RANDOM % 50 + 10))
        echo "$(date) |  + Dock not running, waiting [$delay] seconds"
        sleep $delay
    done
    echo "$(date) | Dock is here, lets carry on"
}

## Install App using Brew Function
function installBrewApp() {

    #################################################################################################################
    #################################################################################################################
    ##
    ##  This function takes the following global variables and installs the app using Homebrew
    ##
    ##  Functions
    ##
    ##  Variables
    ##
    ##      $brewApp = name of Application to be installed by Brew
    ##
    ###############################################################
    ###############################################################

    cd /opt
    if [[ $(uname -m) == 'arm64' ]]; then
        # Apple Silicon
        brewPath="/opt/homebrew/bin/brew"
    else
        # Intel
        brewPath="/usr/local/Homebrew/bin/brew"
    fi

    echo "$(date) | Installing $brewApp using Homebrew"
    if $brewPath list $1 &>/dev/null; then
        echo "$(date) | Application ${1} is already installed"
        $brewPath upgrade $1
    else
        $brewPath install $1
        echo "$(date) | Application $1 is installed"
    fi

}

## Function to start logging
function startLog() {

    ###################################################
    ###################################################
    ##
    ##  start logging - Output to log file and STDOUT
    ##
    ####################
    ####################

    if [[ ! -d "$logandmetadir" ]]; then
        ## Creating Metadirectory
        echo "$(date) | Creating [$logandmetadir] to store logs"
        mkdir -p "$logandmetadir"
    fi

    exec &> >(tee -a "$log")

}

# Begin Script Body
## Initiate logging
startLog

echo ""
echo "##############################################################"
echo "# $(date) | Logging install of [$brewApp] to [$log]"
echo "############################################################"
echo ""

## Wait for Desktop
waitForDesktop

## Install Brew
installBrew

## Install Brew App
installBrewApp $brewApp
