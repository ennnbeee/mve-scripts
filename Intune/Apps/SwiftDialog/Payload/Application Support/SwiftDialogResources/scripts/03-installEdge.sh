#!/bin/bash
#set -x

############################################################################################
##
## Script to install the latest Edge stable channel from Microsoft CDN Servers
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

# Define variables
weburl="https://go.microsoft.com/fwlink/?linkid=2093504"                                        # What is the Azure Blob Storage URL?
appname="Microsoft Edge"                                                                        # The name of our App deployment script
app="Microsoft Edge.app"                                                                        # The actual name of our App once installed
logandmetadir="/Library/Application Support/Microsoft/IntuneScripts/installEdge"                               # The location of our logs and last updated data
processpath="/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge"                    # The process name of the App we are installing
terminateprocess="false"                                                                        # Do we want to terminate the running process? If false we'll wait until its not running
autoUpdate="true"                                                                              # If true, application updates itself and we should not attempt to update
waitForSplashScreen=true                                                                    # Should we hold the script until an onboard splashscreen is running?   
SplashScreenProcess="Dialog"                                                                # If we do wait for a splash screen, what's the process name? Octory | Dialog

# Generated variables
tempdir=$(mktemp -d)
log="$logandmetadir/$appname.log"                                               # The location of the script log file
metafile="$logandmetadir/$appname.meta"                                         # The location of our meta file (for updates)

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
            delay=$(( $RANDOM % 50 + 10 ))
        else
            delay=$fixedDelay
        fi

        echo "$(date) |  + Another instance of $processName is running, waiting [$delay] seconds"
        sleep $delay
    done
    
    echo "$(date) | No instances of [$processName] found, safe to proceed"

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

    #download the file
    #updateSplashScreen installing              # Octory
    updateSplashScreen wait Downloading         # Swift Dialog
    echo "$(date) | Downloading $appname"

    cd "$tempdir"
    curl -f -s --connect-timeout 30 --retry 5 --retry-delay 60 -L -J -o "edge.pkg" "$weburl"
    if [ $? == 0 ]; then

            # We have downloaded a file, we need to know what the file is called and what type of file it is
            tempSearchPath="$tempdir/*"
            for f in $tempSearchPath; do
                tempfile=$f
            done

            case $tempfile in

            *.pkg|*.PKG)
                packageType="PKG"
                ;;

            *.zip|*.ZIP)
                packageType="ZIP"
                ;;

            *.dmg|*.DMG)
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

                if [[ "$metadata" == *"bzip2 compressed data"* ]] || [[ "$metadata" == *"zlib compressed data"* ]] ; then
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
    
        echo "$(date) | Failure to download [$weburl] to [$tempfile]"
        #updateSplashScreen failed              # Octory
        updateSplashScreen fail Failed         # Swift Dialog
        exit 1
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

    ## Is the app already installed?
    if [ -d "/Applications/$app" ]; then

    # App is installed, if it's updates are handled by MAU we should quietly exit
    if [[ $autoUpdate == "true" ]]; then
        echo "$(date) | [$appname] is already installed and handles updates itself, exiting"
        updateSplashScreen success Installed         # Swift Dialog
        exit 0;
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
                    updateSplashScreen success Installed         # Swift Dialog
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


    # Check if app is running, if it is we need to wait.
    waitForProcess "$processpath" "300" "$terminateprocess"

    echo "$(date) | Installing $appname"


    # Update Octory monitor
    #updateSplashScreen installing              # Octory
    updateSplashScreen wait Installing         # Swift Dialog

    # Remove existing files if present
    if [[ -d "/Applications/$app" ]]; then
        rm -rf "/Applications/$app"
    fi

    installer -pkg "$tempfile" -target /Applications

    # Checking if the app was installed successfully
    if [ "$?" = "0" ]; then

        echo "$(date) | $appname Installed"
        echo "$(date) | Cleaning Up"
        rm -rf "$tempdir"

        echo "$(date) | Application [$appname] succesfully installed"
        fetchLastModifiedDate update
        #updateSplashScreen installed                   # Octory
        updateSplashScreen success Installed            # Swift Dialog
        exit 0

    else

        echo "$(date) | Failed to install $appname"
        rm -rf "$tempdir"
        #updateSplashScreen failed                   # Octory
        updateSplashScreen fail Failed                  # Swift Dialog
        exit 1
    fi

}

## Install DMG Function
function installDMG () {

    #################################################################################################################
    #################################################################################################################
    ##
    ##  This function takes the following global variables and installs the DMG file into /Applications
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


    # Check if app is running, if it is we need to wait.
    waitForProcess "$processpath" "300" "$terminateprocess"



    echo "$(date) | Installing [$appname]"
    updateOctory installing
    #updateSplashScreen installing                      # Octory
    updateSplashScreen wait Installing                  # Swift Dialog

    # Mount the dmg file...
    volume="$tempdir/$appname"
    echo "$(date) | Mounting Image"
    hdiutil attach -quiet -nobrowse -mountpoint "$volume" "$tempfile"

    # Remove existing files if present
    if [[ -d "/Applications/$app" ]]; then
        echo "$(date) | Removing existing files"
        rm -rf "/Applications/$app"
    fi

    # Sync the application and unmount once complete
    echo "$(date) | Copying app files to /Applications/$app"
    rsync -a "$volume"/*.app/ "/Applications/$app"

    # Unmount the dmg
    echo "$(date) | Un-mounting [$volume]"
    hdiutil detach -quiet "$volume"

    # Checking if the app was installed successfully

    if [[ -a "/Applications/$app" ]]; then

        echo "$(date) | [$appname] Installed"
        echo "$(date) | Cleaning Up"
        rm -rf "$tempfile"

        echo "$(date) | Fixing up permissions"
        sudo chown -R root:wheel "/Applications/$app"
        echo "$(date) | Application [$appname] succesfully installed"
        fetchLastModifiedDate update
        #updateSplashScreen installed                       # Octory
        updateSplashScreen success Installed                # Swift Dialog
        exit 0
    else
        echo "$(date) | Failed to install [$appname]"
        rm -rf "$tempdir"
        #updateSplashScreen failed                         # Octory
        updateSplashScreen fail Failed                     # Swift Dialog
        exit 1
    fi

}

## Install ZIP Function
function installZIP () {

    #################################################################################################################
    #################################################################################################################
    ##
    ##  This function takes the following global variables and installs the DMG file into /Applications
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


    # Check if app is running, if it is we need to wait.
    waitForProcess "$processpath" "300" "$terminateprocess"

    echo "$(date) | Installing $appname"
    #updateSplashScreen installing                         # Octory
    updateSplashScreen wait Installing                     # Swift Dialog
    # Change into temp dir
    cd "$tempdir"
    if [ "$?" = "0" ]; then
      echo "$(date) | Changed current directory to $tempdir"
    else
      echo "$(date) | failed to change to $tempfile"
      if [ -d "$tempdir" ]; then rm -rf $tempdir; fi
        #updateSplashScreen failed                         # Octory
        updateSplashScreen fail Failed                     # Swift Dialog
      exit 1
    fi

    # Unzip files in temp dir
    unzip -qq -o "$tempfile"
    if [ "$?" = "0" ]; then
      echo "$(date) | $tempfile unzipped"
    else
      echo "$(date) | failed to unzip $tempfile"
      if [ -d "$tempdir" ]; then rm -rf $tempdir; fi
        #updateSplashScreen failed                         # Octory
        updateSplashScreen fail Failed                     # Swift Dialog
      exit 1
    fi

    # If app is already installed, remove all old files
    if [[ -a "/Applications/$app" ]]; then
    
      echo "$(date) | Removing old installation at /Applications/$app"
      rm -rf "/Applications/$app"
    
    fi

    # Copy over new files
    rsync -a "$app/" "/Applications/$app"
    if [ "$?" = "0" ]; then
      echo "$(date) | $appname moved into /Applications"
    else
      echo "$(date) | failed to move $appname to /Applications"
      if [ -d "$tempdir" ]; then rm -rf $tempdir; fi
        #updateSplashScreen failed                         # Octory
        updateSplashScreen fail Failed                     # Swift Dialog
      exit 1
    fi

    # Make sure permissions are correct
    echo "$(date) | Fix up permissions"
    sudo chown -R root:wheel "/Applications/$app"
    if [ "$?" = "0" ]; then
      echo "$(date) | correctly applied permissions to $appname"
    else
      echo "$(date) | failed to apply permissions to $appname"
      if [ -d "$tempdir" ]; then rm -rf $tempdir; fi
        #updateSplashScreen failed                         # Octory
        updateSplashScreen fail Failed                     # Swift Dialog
      exit 1
    fi

    # Checking if the app was installed successfully
    if [ "$?" = "0" ]; then
        if [[ -a "/Applications/$app" ]]; then

            echo "$(date) | $appname Installed"
            #updateSplashScreen installed                            # Octory
            updateSplashScreen success Installed                     # Swift Dialog
            echo "$(date) | Cleaning Up"
            rm -rf "$tempfile"

            # Update metadata
            fetchLastModifiedDate update

            echo "$(date) | Fixing up permissions"
            sudo chown -R root:wheel "/Applications/$app"
            echo "$(date) | Application [$appname] succesfully installed"
            exit 0
        else
            echo "$(date) | Failed to install $appname"
            exit 1
        fi
    else

        # Something went wrong here, either the download failed or the install Failed
        # intune will pick up the exit status and the IT Pro can use that to determine what went wrong.
        # Intune can also return the log file if requested by the admin
        
        echo "$(date) | Failed to install $appname"
        if [ -d "$tempdir" ]; then rm -rf $tempdir; fi
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
    ## 
    ##  Octory
    ##
    ##      Param 1 = State
    ##
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

# Install Rosetta if we need it
checkForRosetta2

# Test if we need to install or update
updateCheck

# Wait for Desktop
waitForDesktop

# Download app
downloadApp

# Install PKG file
if [[ $packageType == "PKG" ]]; then
    installPKG
fi

# Install PKG file
if [[ $packageType == "ZIP" ]]; then
    installZIP
fi

# Install PKG file
if [[ $packageType == "DMG" ]]; then
    installDMG
fi