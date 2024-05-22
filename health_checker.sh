#!/bin/bash
#################################
# This tool is inspired by SupportApp by Root3
# https://github.com/root3nl/SupportApp/tree/master
# Pre Flight checks and jamf variables come from Dan Snelson (snelson.us)
# Problems solved and ideas taken from Perry Driscoll <https://github.com/PezzaD84>

# By Matt Jerome
# Initiall Built 05/22/2024
# v0.0.1 - Initial Devleopment
#################################

scriptLog="${4:-"/var/log/health_checker.log"}" # Parameter 4: Script Log Location (i.e., Your organization's default location for client-side logs)
logo="${5:-""}" # Parameter 5: logo Location
###################################################################################################
#
# Pre-flight Checks
#
####################################################################################################
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Client-side Logging
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [[ ! -f "${scriptLog}" ]]; then
	touch "${scriptLog}"
fi

if [[ $logo == "" ]]; then
	logo="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/com.apple.macbookpro-14-2021-silver.icns"
fi

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Client-side Script Logging Function
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function updateScriptLog() {
	echo -e "$( date +%Y-%m-%d\ %H:%M:%S ) - ${1}" | tee -a "${scriptLog}"
}


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Computer Information
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
computerName=$(hostname)
serialNumber=$(system_profiler SPHardwareDataType | sed '/^ *Serial Number (system):*/!d;s###;s/ //')
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Quit the Script
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
function quitScript() {
	
	updateScriptLog "QUIT SCRIPT: Exiting …"
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Current Logged-in User Function
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function currentLoggedInUser() {
	loggedInUser=$( echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ { print $3 }' )
	updateScriptLog "PRE-FLIGHT CHECK: Current Logged-in User: ${loggedInUser}"
}


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Swift dialog
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
DialogInstall(){
	pkgfile="SwiftDialog.pkg"
	logfile="/Library/Logs/SwiftDialogInstallScript.log"
	URL="https://github.com$(curl -sfL "$(curl -sfL "https://github.com/bartreardon/swiftDialog/releases/latest" | tr '"' "\n" | grep -i "expanded_assets" | head -1)" | tr '"' "\n" | grep -i "^/.*\/releases\/download\/.*\.pkg" | head -1)"
	
	# Start Log entries
	echo "--" >> ${logfile}
	echo "`date`: Downloading latest version." >> ${logfile}
	
	# Download installer
	curl -s -L -J -o /tmp/${pkgfile} ${URL}
	echo "`date`: Installing..." >> ${logfile}
	
	# Change to installer directory
	cd /tmp
	
	# Install application
	sudo installer -pkg ${pkgfile} -target /
	sleep 5
	echo "`date`: Deleting package installer." >> ${logfile}
	
	# Remove downloaded installer
	rm /tmp/"${pkgfile}"
}

##############################################################
# Check if SwiftDialog is installed (SwiftDialog created by Bart Reardon https://github.com/bartreardon/swiftDialog)
##############################################################

if ! command -v dialog &> /dev/null
then
	echo "SwiftDialog is not installed. App will be installed now....."
	sleep 2
	
	DialogInstall
	
else
	echo "SwiftDialog is installed. Checking installed version....."
	
	installedVersion=$(dialog -v | sed 's/./ /6' | awk '{print $1}')
	
	latestVersion=$(curl -sfL "https://github.com/bartreardon/swiftDialog/releases/latest" | tr '"' "\n" | grep -i "expanded_assets" | head -1 | tr '/' ' ' | awk '{print $7}' | tr -d 'v' | awk -F '-' '{print $1}')
	
	if [[ $installedVersion != $latestVersion ]]; then
		echo "Dialog needs updating"
		DialogInstall
	else
		echo "Dialog is up to date. Continuing to assemble...."
	fi
	sleep 3
fi
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# System Checks
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

currentLoggedInUser 
####### Battery Status 
battery_condition=$(system_profiler SPPowerDataType | sed -n -e 's/^.*Condition: //p')
updateScriptLog "Battery health: $battery_condition"
battery_cycle=$(system_profiler SPPowerDataType | sed -n -e 's/^.*Cycle Count: //p')
updateScriptLog "Battery Cycle Count: $battery_cycle"

####### Get last Jamf Pro check-in time from jamf.log
last_check_in_time=$(grep "Checking for policies triggered by \"recurring check-in\"" "/private/var/log/jamf.log" | tail -n 1 | awk '{ print $2,$3,$4 }')
updateScriptLog "Last Jamf Checkin Time: $last_check_in_time"
sw_vers=$(sw_vers | grep "ProductVersion" | awk '{print $2}')
updateScriptLog "Current macOS Version: $sw_vers"


####### Available Updates	
# Run software update and store the result
	updates=$(softwareupdate -l 2>&1)

# Check if any updates are available
	if [[ $updates == *"No new software available"* ]]; then
		updateStatus="No macOS Updates Available."
		updateScriptLog  "No macOs updates available"
	else
		updateScriptLog "macOS Updates are available"
		updateStatus="macOS Updates are available"
		updateScriptLog "$updates"
	fi

####### Storage usage
	
# Extract total storage from the result and remove the characters 'Gi'
total_storage=$(system_profiler SPStorageDataType -detaillevel mini | grep "Macintosh HD - Data:" -C 17 | sed -n 6p | awk '{print $2, $3}')
updateScriptLog "Total Storage Used is $total_storage_readable GB"
# Extract available storage from the result and remove the characters 'Gi'
available_storage=$(system_profiler SPStorageDataType -detaillevel mini | grep "Macintosh HD - Data:" -C 17 | sed -n 5p | awk '{print $2, $3}')
updateScriptLog "Total Available Storage is $available_storage"


####### Drive SMART information
smartStatus=$(system_profiler SPStorageDataType -detaillevel mini | grep "Macintosh HD - Data:" -C 17 | sed -n 20p | awk '{print $3}')
	
####### Network information
ipAddress="$(ipconfig getifaddr $(networksetup -listallhardwareports | awk '/Hardware Port: Wi-Fi/{getline; print $2}'))"
updateScriptLog "Current IP Address: $ipAddress"
	
#####make and model, SMART Status, other users logged in?,updates last run

####### Last Reboot
boottime=$(sysctl kern.boottime | awk '{print $5}' | tr -d ,) # produces EPOCH time
formattedTime=$(date -jf %s "$boottime" +%F\ %T) #formats to a readable time
updateScriptLog "Last Reboot: $formattedTime"

####### Total RAM
hwmemsize=$(sysctl -n hw.memsize)
ramsize=$(expr $hwmemsize / $((1024**3)))
updateScriptLog  "System Memory: ${ramsize} GB"

####### Current Network
current_network=$(networksetup -getairportnetwork en0 | sed -E 's,^Current Wi-Fi Network: (.+)$,\1,')
updateScriptLog "Current WiFi Network: $current_network"

####### CPU
cpu=$(system_profiler SPHardwareDataType -detailLevel mini | grep "Chip:" | awk '{print $2, $3, $4'})
updateScriptLog "CPU: $cpu"

####### Computer Model
computerModel=$(system_profiler SPHardwareDataType -detailLevel mini | grep "Model Name:" | awk '{print $3,$4}')
updateScriptLog "Computer Model: $computerModel"

####### Last macOS Update
lastUpdateDate=$(system_profiler SPInstallHistoryDataType | grep "macOS" -C 4 | sed -n 7p | awk '{print substr($3, 1, length($3)-1)}')
updateScriptLog "Last macOS Update: $lastUpdateDate"

####### Filevault 2 Status
fvstatus=$(fdesetup status)

#########################################################################################
# Information List into a json file
#########################################################################################
	
	cat << EOF > /tmp/dialogjson.json
{
	"listitem" : [
		{"title" : "Current Network:", "icon" : "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/GenericNetworkIcon.icns", "statustext" : "$current_network"},
		{"title" : "IP Address:", "icon" : "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/AirDrop.icns", "statustext" : "$ipAddress"},
		{"title" : "Free Disk Space:", "icon" : "https://ics.services.jamfcloud.com/icon/hash_522d1d726357cda2b122810601899663e468a065db3d66046778ceecb6e81c2b", "statustext" : "$available_storage"},
		{"title" : "Storage SMART Status:", "icon" : "https://ics.services.jamfcloud.com/icon/hash_522d1d726357cda2b122810601899663e468a065db3d66046778ceecb6e81c2b", "statustext" : "$smartStatus"},
		{"title" : "Last Jamf Checkin:", "icon" : "https://resources.jamf.com/images/logos/Jamf-Icon-color.png", "statustext" : "$last_check_in_time"},
		{"title" : "Last Reboot:", "icon" : "https://use2.ics.services.jamfcloud.com/icon/hash_5d46c28310a0730f80d84afbfc5889bc4af8a590704bb9c41b87fc09679d3ebd", "statustext" : "$formattedTime"},
		{"title" : "Last macOS Update:", "icon" : "https://use2.ics.services.jamfcloud.com/icon/hash_b8320cee6b2508e74092e3986ee434850c95ad79e698f91eff1facef89b09303", "statustext" : "$lastUpdateDate"},
		{"title" : "Battery Condition:", "icon" : "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/ToolbarInfo.icns", "statustext" : "$battery_condition"},
		{"title" : "Battery Cycle Count:", "icon" : "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/ToolbarInfo.icns", "statustext" : "$battery_cycle"},
		{"title" : "Encryption Status:", "icon" : "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/FileVaultIcon.icns", "statustext" : "$fvstatus"}

	]
}
EOF

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Display in Swift Dialog Box
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
	
/usr/local/bin/dialog --message none --icon $logo --height 700 --title "Computer Health Check" --moveable --jsonfile /tmp/dialogjson.json --infobox "Current User: $loggedInUser\n \nComputer Model: $computerModel \n \n CPU: $cpu \n \n Useable Storage: $total_storage \n\nRAM: $ramsize GB\n \n macOS Version: $sw_vers \n\n Update Status: $updateStatus\n\n Computer Name: $computerName \n\nSerial Number: $serialNumber" --button1Text "Exit"

if [[ -f /tmp/dialogjson.json ]]; then
	echo "json file found, deleting"
	rm /tmp/dialogjson.json
	echo "removed json file"
fi
exit 0