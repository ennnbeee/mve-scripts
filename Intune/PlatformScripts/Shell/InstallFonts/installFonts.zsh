#!/bin/zsh
#set -x

############################################################################################
##
## Script to Install Fonts on macOS devices using Intune
##
## VER 1.0.0
##
############################################################################################

# User Defined variables

fontPackageUrl="https://github.com/ennnbeee/mve-scripts/raw/refs/heads/main/Intune/PlatformScripts/Shell/InstallFonts/fonts.zip" # Enter your own URL here
appName="fonts"
fontDir="/Library/Fonts/" # All users fonts folder

# Generated variables
tempDir=$(mktemp -d)
logandMetaDir="/Library/Logs/Microsoft/IntuneScripts/$appName" # The location of our logs and last updated data
log="$logandMetaDir/$appName.log"                              # The location of the script log file

# Start logging
if [[ ! -d "$logandMetaDir" ]]; then
    ## Creating Metadirectory
    echo "$(date) | Creating [$logandMetaDir] to store logs"
    mkdir -p "$logandMetaDir"
fi

echo "$(date) | Starting logging to [$log]"
exec > >(tee -a "$log") 2>&1

echo "$(date) | Starting Script..."
cd "$tempDir"

# Maximum number of download attempts
attempts=5

# Download the zip file with a while loop
attempt=1
while [ $attempt -le $attempts ]; do
    echo "$(date) | Attempting to downloading file  [$downloadAttempts]..."
    downloadResult=$(/usr/bin/curl -sL ${fontPackageUrl} -o ${tempDir}/fonts.zip -w "%{http_code}")

    if [[ $downloadResult -eq 200 ]]; then
        echo "$(date) | Unzipping font  files..."
        unzip -qq -o fonts.zip

    else
        # If the download was not successful we will wait here for 2 seconds.
        attempt=$((attempt + 1))
        sleep 2
    fi

    if [[ $downloadAttempts -gt 5 ]]; then
        echo "$(date) | Failed to download and unzip font files after $attempts attempts, exiting..."
        exit 1
    fi

done

# Loop through each font file in the temporary directory
for fontFile in "$tempDir"/*; do
    fontName=$(basename "$fontFile")
    fontDest="$fontDir/$fontName"

    if [[ "$fontFile" == *.ttf || "$fontFile" == *.otf || "$fontFile" == *.dfont || "$fontFile" == *.ttc ]]; then

        # Check if the font file already exists in the destination directory
        if [ ! -f "$fontDest" ]; then
            # Copy the font file to the destination directory
            mv "$fontFile" "$fontDest"
            echo "$(date) | Moved $fontName to $fontDir"
        else
            echo "$(date) | $fontName already exists in $fontDir"
        fi
    else
        echo "$(date) | $fontName is not a supported font file"
    fi
done

rm -rf "$tempDir"

echo "$(date) | Script completed."