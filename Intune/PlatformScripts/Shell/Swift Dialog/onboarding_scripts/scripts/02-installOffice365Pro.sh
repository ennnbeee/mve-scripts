#!/bin/bash
#set -x

############################################################################################
##
## Script to install the latest Office 365 Pro
##
############################################################################################

## Copyright (c) 2020 Microsoft Corp. All rights reserved.
## Scripts are not supported under any Microsoft standard support program or service. The scripts are provided AS IS without warranty of any kind.
## Microsoft disclaims all implied warranties including, without limitation, any implied warranties of merchantability or of fitness for a
## particular purpose. The entire risk arising out of the use or performance of the scripts and documentation remains with you. In no event shall
## Microsoft, its authors, or anyone else involved in the creation, production, or delivery of the scripts be liable for any damages whatsoever
## (including, without limitation, damages for loss of business profits, business interruption, loss of business information, or other pecuniary
## loss) arising out of the use of or inability to use the sample scripts or documentation, even if Microsoft has been advised of the possibility
## of such damages.
## Feedback: neiljohn@microsoft.com

# User Defined variables
weburl="https://go.microsoft.com/fwlink/?linkid=2009112"                            # What is the Azure Blob Storage URL?
appname="Microsoft Office"                                                          # The name of our App deployment script (also used for splash screen monitor)
logandmetadir="/Library/Application Support/Microsoft/IntuneScripts/installOffice"  # The location of our logs and last updated data
terminateprocess="true"                                                             # Do we want to terminate the running process? If false we'll wait until its not running
autoUpdate="true"                                                                   # Application updates itself, if already installed we should exit

# Generated variables
tempdir=$(mktemp -d)
tempfile="$appname.pkg"
log="$logandmetadir/$appname.log"                                               # The location of the script log file
metafile="$logandmetadir/$appname.meta"                                         # The location of our meta file (for updates)

function installAria2c () {

    #####################################
    ## Aria2c installation
    #####################
    ARIA2="/usr/local/aria2/bin/aria2c"
    aria2Url="https://github.com/aria2/aria2/releases/download/release-1.35.0/aria2-1.35.0-osx-darwin.dmg"
    if [[ -f $ARIA2 ]]; then
        echo "$(date) | Aria2 already installed, nothing to do"
    else
        echo "$(date) | Aria2 missing, lets download and install"
        filename=$(basename "$aria2Url")
        output="$tempdir/$filename"
        #curl -L -o "$output" "$aria2Url"
        curl -f -s --connect-timeout 30 --retry 5 --retry-delay 60 -L -o "$output" "$aria2Url"
        if [ $? -ne 0 ]; then
            echo "$(date) | Aria download failed"
            echo "$(date) | Output: [$output]"
            echo "$(date) | URL [$aria2Url]"
            exit 1
        else
            echo "$(date) | Downloaded aria2"
        fi

        # Mount aria2 DMG
        mountpoint="$tempdir/aria2"
        echo "$(date) | Mounting Aria DMG..."
        hdiutil attach -quiet -nobrowse -mountpoint "$mountpoint" "$output"
        if [ $? -ne 0 ]; then
            echo "$(date) | Aria mount failed"
            echo "$(date) | Mount: [$mountpoint]"
            echo "$(date) | Temp File [$output]"
            exit 1
        else
            echo "$(date) | Mounted DMG"
        fi
        
        # Install aria2 PKG from inside the DMG
        sudo installer -pkg "$mountpoint/aria2.pkg" -target /
        if [ $? -ne 0 ]; then
            echo "$(date) | Install failed"
            echo "$(date) | PKG: [$mountpoint/aria2.pkg]"
            exit 1
        else
            echo "$(date) | Aria2 installed"
            hdiutil detach -quiet "$mountpoint"
        fi
    rm -rf "$output"
    fi


}

# function to delay script if the specified process is running
waitForProcess () {

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
            delay=$(( $RANDOM % 50 + 10 ))
        else
            delay=$fixedDelay
        fi

        echo "$(date) |  + Another instance of $processName is running, waiting [$delay] seconds"
        sleep $delay
    done

    echo "$(date) | No instances of [$processName] found, safe to proceed"

}

# Function to change the download URL to an older version if the current version isn't supported on this Mac
function OfficeURLCheck() {

    # Download location for latest version of Office for Mac 2019
    weburl="https://go.microsoft.com/fwlink/?linkid=2009112" 

    echo "$(date) | Checking that the version of Office we have will work on this Mac"
    os_ver=$(sw_vers -productVersion)

    case $os_ver in

    10.10.*)
        echo "$(date) |  + macOS 10.10 Yosemite detected, setting install to Office 2016 v16.16"
        weburl="https://officecdn-microsoft-com.akamaized.net/pr/C1297A47-86C4-4C1F-97FA-950631F94777/MacAutoupdate/Microsoft_Office_16.16.20091400_Installer.pkg"
        unset localcopy # Note, enter your own localcopy URL if you have one here
        ;;

    10.11.*)
        echo "$(date) |  + macOS 10.11 El Capitan detected, setting install to Office 2016 v16.16"
        weburl="https://officecdn-microsoft-com.akamaized.net/pr/C1297A47-86C4-4C1F-97FA-950631F94777/MacAutoupdate/Microsoft_Office_16.16.20091400_Installer.pkg"
        unset localcopy # Note, enter your own localcopy URL if you have one here
        ;;

    10.12.*)
        echo "$(date) |  + macOS 10.12 Sierra detected, setting install to Office 2016 v16.30"
        weburl="https://officecdn-microsoft-com.akamaized.net/pr/C1297A47-86C4-4C1F-97FA-950631F94777/MacAutoupdate/Microsoft_Office_16.30.19101301_Installer.pkg"
        unset localcopy # Note, enter your own localcopy URL if you have one here
        ;;

    10.13.*)
        echo "$(date) |  + macOS 10.13 High Sierra detected, setting install to Office 2019 v16.43"
        weburl="https://officecdn-microsoft-com.akamaized.net/pr/C1297A47-86C4-4C1F-97FA-950631F94777/MacAutoupdate/Microsoft_Office_16.43.20110804_Installer.pkg"
        unset localcopy # Note, enter your own localcopy URL if you have one here
        ;;

    10.14.*)
        echo "$(date) |  + macOS 10.14 Mojave detected, setting install to Office 2019 v16.54"
        weburl="https://officecdnmac.microsoft.com/pr/C1297A47-86C4-4C1F-97FA-950631F94777/MacAutoupdate/Microsoft_Office_16.54.21101001_BusinessPro_Installer.pkg"
        unset localcopy # Note, enter your own localcopy URL if you have one here
        ;;

    10.15.*)
        
        echo "$(date) |  + macOS 10.15 Catalina detected, setting install to Office 2019 v16.66"
        weburl="https://officecdnmac.microsoft.com/pr/C1297A47-86C4-4C1F-97FA-950631F94777/MacAutoupdate/Microsoft_Office_16.66.22101101_BusinessPro_Installer.pkg"
        unset localcopy # Note, enter your own localcopy URL if you have one here
        ;;

    11.*)
        echo "$(date) |  + macOS 11.x Big Sur detected, installing latest available version"
        ;;

    12.*)
        echo "$(date) |  + macOS 12.x Monteray detected, installing latest available version"
        ;;

    13.*)
        echo "$(date) |  + macOS 13.x Ventura detected, installing latest available version"
        ;;

    *)
        echo "$(date) |  + Unknown OS $os_ver"
        ;;
    esac
}

# function to check if we need Rosetta 2
checkForRosetta2 () {

    #################################################################################################################
    #################################################################################################################
    ##
    ##  Simple function to install Rosetta 2 if needed.
    ##
    ##  Functions
    ##
    ##      waitForProcess (used to pause script if another instance of softwareupdate is running)
    ##
    ##  Variables
    ##
    ##      None
    ##
    ###############################################################
    ###############################################################

    

    echo "$(date) | Checking if we need Rosetta 2 or not"

    # if Software update is already running, we need to wait...
    waitForProcess "/usr/sbin/softwareupdate"


    ## Note, Rosetta detection code from https://derflounder.wordpress.com/2020/11/17/installing-rosetta-2-on-apple-silicon-macs/
    OLDIFS=$IFS
    IFS='.' read osvers_major osvers_minor osvers_dot_version <<< "$(/usr/bin/sw_vers -productVersion)"
    IFS=$OLDIFS

    if [[ ${osvers_major} -ge 11 ]]; then

        # Check to see if the Mac needs Rosetta installed by testing the processor

        processor=$(/usr/sbin/sysctl -n machdep.cpu.brand_string | grep -o "Intel")
        
        if [[ -n "$processor" ]]; then
            echo "$(date) | $processor processor installed. No need to install Rosetta."
        else

            # Check for Rosetta "oahd" process. If not found,
            # perform a non-interactive install of Rosetta.
            
            if /usr/bin/pgrep oahd >/dev/null 2>&1; then
                echo "$(date) | Rosetta is already installed and running. Nothing to do."
            else
                /usr/sbin/softwareupdate --install-rosetta --agree-to-license
            
                if [[ $? -eq 0 ]]; then
                    echo "$(date) | Rosetta has been successfully installed."
                else
                    echo "$(date) | Rosetta installation failed!"
                    exitcode=1
                fi
            fi
        fi
        else
            echo "$(date) | Mac is running macOS $osvers_major.$osvers_minor.$osvers_dot_version."
            echo "$(date) | No need to install Rosetta on this version of macOS."
    fi

}

# Function to update the last modified date for this app
fetchLastModifiedDate() {

    #################################################################################################################
    #################################################################################################################
    ##
    ##  This function takes the following global variables and downloads the URL provided to a temporary location
    ##
    ##  Functions
    ##
    ##      none
    ##
    ##  Variables
    ##
    ##      $logandmetadir = Directory to read nand write meta data to
    ##      $metafile = Location of meta file (used to store last update time)
    ##      $weburl = URL of download location
    ##      $tempfile = location of temporary DMG file downloaded
    ##      $lastmodified = Generated by the function as the last-modified http header from the curl request
    ##
    ##  Notes
    ##
    ##      If called with "fetchLastModifiedDate update" the function will overwrite the current lastmodified date into metafile
    ##
    ###############################################################
    ###############################################################

    ## Check if the log directory has been created
    if [[ ! -d "$logandmetadir" ]]; then
        ## Creating Metadirectory
        echo "$(date) | Creating [$logandmetadir] to store metadata"
        mkdir -p "$logandmetadir"
    fi

    # generate the last modified date of the file we need to download
    lastmodified=$(curl -sIL "$weburl" | grep -i "last-modified" | awk '{$1=""; print $0}' | awk '{ sub(/^[ \t]+/, ""); print }' | tr -d '\r')

    if [[ $1 == "update" ]]; then
        echo "$(date) | Writing last modifieddate [$lastmodified] to [$metafile]"
        echo "$lastmodified" > "$metafile"
    fi

}

function downloadApp () {

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
    ##      $weburl = URL of download location
    ##      $tempfile = location of temporary DMG file downloaded
    ##
    ###############################################################
    ###############################################################

    echo "$(date) | Starting downlading of [$appname]"

    # Check download location to see if we can handle the latest version of Office
    OfficeURLCheck

    # If local copy is defined, let's try and download it...
    if [ "$localcopy" ]; then

        updateSplashScreen wait Downloading     # Swift Dialog
        # Check to see if we can access our local copy of Office
        echo "$(date) | Downloading [$localcopy] to [$tempfile]"
        rm -rf "$tempfile" > /dev/null 2>&1
        curl -f -s -L -o "$tempfile" "$localcopy"
        if [ $? == 0 ]; then
            echo "$(date) | Local copy of $appname downloaded at $tempfile"
            downloadcomplete="true"
        else
            echo "$(date) | Failed to download Local copy [$localcopy] to [$tempfile]"
        fi
    fi

    # If we failed to download the local copy, or it wasn't defined then try to download from CDN
    if [[ "$downloadcomplete" != "true" ]]; then

        updateSplashScreen wait Downloading     # Swift Dialog
        rm -rf "$tempfile" > /dev/null 2>&1
        echo "$(date) | Downloading [$weburl] to [$tempfile]"
        #curl -f -s --connect-timeout 60 --retry 10 --retry-delay 30 -L -o "$tempfile" "$weburl"
        $ARIA2 -q -x16 -s16 -d "$tempdir" -o "$tempfile" "$weburl" --download-result=hide --summary-interval=0
        if [ $? == 0 ]; then
            echo "$(date) | Downloaded $weburl to $tempdir/$tempfile"
        else

            echo "$(date) | Failure to download $weburl to $tempdir/$tempfile"
            updateSplashScreen fail Download failed     # Swift Dialog
            exit 1

        fi

    fi

}

# Function to check if we need to update or not
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

    # App Array for Office 365 Apps for Mac
    OfficeApps=( "/Applications/Microsoft Excel.app"
                "/Applications/Microsoft OneNote.app"
                "/Applications/Microsoft Outlook.app"
                "/Applications/Microsoft PowerPoint.app"
                "/Applications/Microsoft Teams.app"
                "/Applications/Microsoft Word.app")

    for i in "${OfficeApps[@]}"; do
        if [[ ! -e "$i" ]]; then
            echo "$(date) | [$i] not installed, need to perform full installation"
            let missingappcount=$missingappcount+1
        fi
    done

    if [[ ! "$missingappcount" ]]; then

        # App is installed, if it's updates are handled by MAU we should quietly exit
        if [[ $autoUpdate == "true" ]]; then
            echo "$(date) | [$appname] is already installed and handles updates itself, exiting"
            updateSplashScreen success Installed         # Swift Dialog
            exit 0;
        fi

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
                    updateSplashScreen success Installed         # Swift Dialog
                    echo "$(date) | Exiting, nothing to do"
                    exit 0
                fi
            else
                echo "$(date) | Meta file [$metafile] not found"
                echo "$(date) | Unable to determine if update required, updating [$appname] anyway"

            fi

        fi

    fi

}

## Install PKG Function
function installPKG () {

    #################################################################################################################
    #################################################################################################################
    ##
    ##  This function takes the following global variables and installs the PKG file
    ##
    ##  Functions
    ##
    ##      isAppRunning (Pauses installation if the process defined in global variable $processpath is running )
    ##      fetchLastModifiedDate (Called with update flag which causes the function to write the new lastmodified date to the metadata file)
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




    echo "$(date) | Installing [$appname]"
    updateSplashScreen wait Installing     # Swift Dialog

    installer -pkg "$tempdir/$tempfile" -target /Applications

    # Checking if the app was installed successfully
    if [ "$?" = "0" ]; then

        echo "$(date) | $appname Installed"
        echo "$(date) | Cleaning Up"
        rm -rf "$tempdir"

        echo "$(date) | Writing last modifieddate $lastmodified to $metafile"
        echo "$lastmodified" > "$metafile"

        echo "$(date) | Application [$appname] succesfully installed"
        fetchLastModifiedDate update
        updateSplashScreen success Installed    # Swift Dialog
        exit 0

    else

        echo "$(date) | Failed to install $appname"
        rm -rf "$tempdir"
        updateSplashScreen fail Failed     # Swift Dialog
        exit 1
    fi

}

function updateSplashScreen () {

    #################################################################################################################
    #################################################################################################################
    ##
    ##  This function is designed to update the Splash Screen status (if required)
    ##
    ##
    ##  Parameters (updateSplashScreen parameter1 parameter2
    ##  Swift Dialog
    ##
    ##      Param 1 = Status
    ##      Param 2 = Status Text
    ##
    ###############################################################
    ###############################################################


    # Is Swift Dialog present
    if [[ -a "/Library/Application Support/Dialog/Dialog.app/Contents/MacOS/Dialog" ]]; then


        echo "$(date) | Updating Swift Dialog monitor for [$appname] to [$1]"
        echo listitem: title: $appname, status: $1, statustext: $2 >> /var/tmp/dialog.log 

        # Supported status: wait, success, fail, error, pending or progress:xx


    fi

}

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

# function to delay until the user has finished setup assistant.
waitForDesktop () {
  until ps aux | grep /System/Library/CoreServices/Dock.app/Contents/MacOS/Dock | grep -v grep &>/dev/null; do
    delay=$(( $RANDOM % 50 + 10 ))
    echo "$(date) |  + Dock not running, waiting [$delay] seconds"
    sleep $delay
  done
  echo "$(date) | Dock is here, lets carry on"
}

###################################################################################
###################################################################################
##
## Begin Script Body
##
#####################################
#####################################

# Initiate logging
startLog

echo ""
echo "##############################################################"
echo "# $(date) | Logging install of [$appname] to [$log]"
echo "############################################################"
echo ""

# Install Aria2c if we don't already have it
installAria2c

# Install Rosetta if we need it
checkForRosetta2

# Test if we need to install or update
updateCheck

# Wait for Desktop
waitForDesktop

# Download app
downloadApp

# Install PKG file
installPKG

