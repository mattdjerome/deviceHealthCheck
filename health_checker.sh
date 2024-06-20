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
logo="${5:-"/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/com.apple.macbookpro-16-space-gray.icns"}" # Parameter 5: logo Location
macOSversion1="${6:-"14.5"}" # Parameter 6: minimum version for macOS N
macOSversion2="${7:-"13.5.7"}" # Parameter 7: minimum version for macOS N-1
minimumStorage="${8:-"50"}" # Parameter 8: minimum amount of stroage available in gigabytes
JamfCheckinDelta="${9:-"7"}" # Parameter 9: threshold days since last jamf checkin
LastRebootDelta="${10:-"14"}" # Parameter 10: threshold days since last reboot
batteryCycleCount="${11:-"1000"}" # parameter 11: battery cycle count threshold

#################################################################################################
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
if [ "${battery_condition}" != "Normal" ]; then
	batteryStatusIcon="error"
	updateScriptLog "Battery Condition is not Normal, may require attention"
else
	batteryStatusIcon="success"
	updateScriptLog "Battery Condition is Normal"
fi
battery_cycle=$(system_profiler SPPowerDataType | sed -n -e 's/^.*Cycle Count: //p')
updateScriptLog "Battery Cycle Count: $battery_cycle"
if [[ $battery_cycle -gt 999 ]]; then
	battery_cycle_icon="error"
else
	battery_cycle_icon="success"
fi


####### Get last Jamf Pro check-in time from jamf.log
last_check_in_time=$(grep "Checking for policies triggered by \"recurring check-in\"" "/private/var/log/jamf.log" | tail -n 1 | awk '{ print $2,$3,$4 }')
# Reformat the date to mm/dd/yyyy
# Convert month name to a numeric month
month=$(date -jf "%b" "$(echo $last_check_in_time | awk '{print $1}')" "+%m")
# Extract day and year
day=$(echo $last_check_in_time | awk '{print $2}')

	
# Format the date to mm/dd
checkin_formatted_date="${month}/${day}"

updateScriptLog "Formatted date: ${checkin_formatted_date}"
updateScriptLog "Last Jamf Checkin Time: $checkin_formatted_date"

# Calculate the difference in days
days_diff=$(( seconds_diff / 86400 ))  # 86400 seconds in a day (24 * 60 * 60)
updateScriptLog "The last Jamf check in was ${days_diff} days ago."
if [[ $days_diff -gt 7 ]]; then
	jamf_checkin_icon="error"
else
	jamf_checkin_icon="success"
fi
#
#
####### Get Current OS Version
sw_vers=$(sw_vers | grep "ProductVersion" | awk '{print $2}')
updateScriptLog "Current macOS Version: $sw_vers"
if [ $sw_vers != $macOSversion1 ] && [ $sw_vers != $macOSversion2 ]; then
	macOS_version_icon="error"
else
	macOS_version_icon="success"
fi

####### Available Updates	
# Run software update and store the result
	updates=$(softwareupdate -l 2>&1)

# Check if any updates are available
	if [[ $updates == *"No new software available"* ]]; then
		updateStatus="No macOS Updates Available."
		updateScriptLog  "No macOs updates available."
	else
		updateScriptLog "macOS Updates are available"
		updateStatus="macOS Updates are available."
		updateScriptLog "$updates"
	fi

####### Storage usage
	
# Extract total storage from the result and remove the characters 'Gi'
total_storage=$(system_profiler SPStorageDataType -detaillevel mini | grep "Macintosh HD - Data:" -C 17 | sed -n 6p | awk '{print $2}')
updateScriptLog "Total Storage Used is $total_storage"
# Extract available storage from the result and remove the characters 'Gi'
available_storage=$(system_profiler SPStorageDataType -detaillevel mini | grep "Macintosh HD - Data:" -C 17 | sed -n 5p | awk '{print $2}')
updateScriptLog "Total Available Storage is $available_storage"

if (( $(bc <<<"$available_storage > 50.00") )); then 
	storage_status_icon="success"
	updateScriptLog "Sufficient Storage found. $available_storage GB are available. Above the 50GB threshold"
else
	storage_status_icon="error"
	updateScriptLog "Insufficient Storage found. $available_storage GB are available. Below the 50GB threshold"
fi

####### Drive SMART information
smartStatus=$(system_profiler SPStorageDataType -detaillevel mini | grep "Macintosh HD - Data:" -C 17 | sed -n 20p | awk '{print $3}')
updateScriptLog "SMART Status: $smartStatus"
if [[ $smartStatus != "Verified" ]]; then
	smart_status_icon="error"
else
	smart_status_icon="success"
fi
####### Network information
ipAddress="$(ipconfig getifaddr $(networksetup -listallhardwareports | awk '/Hardware Port: Wi-Fi/{getline; print $2}'))"
updateScriptLog "Current IP Address: $ipAddress"
	
#####make and model, SMART Status, other users logged in?,updates last run

####### Last Reboot
boottime=$(sysctl kern.boottime | awk '{print $5}' | tr -d ,) # produces EPOCH time
formattedTime=$(date -jf %s "$boottime" +%F) #formats to a readable time
last_reboot_formatted=$(date -j -f "%Y-%m-%d" "$formattedTime" +"%m/%d/%Y")
updateScriptLog "Last Reboot: $last_reboot_formatted"
today=$(date +%s)
target_date=$(date -d "$last_reboot_formatted" +%s)
	
# Calculate the difference in days
days_since_reboot=$(( (target_date - today) / 86400 ))
if [[ $days_since_reboot < 14 ]]; then
	last_reboot_icon="success"
	updateScriptLog "Within the 14 day reboot threshold."
else
	last_reboot_icon="error"
	updateScriptLog "Over the 14 day reboot threshold."
fi
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
if [[ $fvstatus != "FileVault is On." ]]; then
	fvstatus_icon="error"
	updateScriptLog "FileVault error."
else
	fvstatus_icon="success"
	updateScriptLog "FileVault is enabled."
fi



####### Crowdstrike Falcon Connection Status
falcon_connect_status=$(sudo /Applications/Falcon.app/Contents/Resources/falconctl stats | grep "State:" | awk '{print $2}')
updateScriptLog "Crowdstrike Falcon is $falcon_connect_status"
if [[ $falcon_connect_status == "connected" ]]; then
	falcon_connect_icon="success"
	falcon_connect_status="Connected"
else
	falcon_connect_icon="error"
	falcon_connect_status="Not Connected"
fi
#########################################################################################
# Information List into a json file
#########################################################################################
	
	cat << EOF > /tmp/dialogjson.json
{
	"listitem" : [
		{"title" : "Current Network:", "icon" : "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/GenericNetworkIcon.icns", "statustext" : "$current_network"},
		{"title" : "IP Address:", "icon" : "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/AirDrop.icns", "statustext" : "$ipAddress"},
		{"title" : "macOS Version:", "icon" : "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/FinderIcon.icns", "status" : "${macOS_version_icon}", "statustext" : "$sw_vers"},
		{"title" : "Free Disk Space:", "icon" : "https://ics.services.jamfcloud.com/icon/hash_522d1d726357cda2b122810601899663e468a065db3d66046778ceecb6e81c2b", "status" : "${storage_status_icon}","statustext" : "$available_storage"},
		{"title" : "Storage SMART Status:", "icon" : "https://ics.services.jamfcloud.com/icon/hash_522d1d726357cda2b122810601899663e468a065db3d66046778ceecb6e81c2b", "status" : "${smart_status_icon}", "statustext" : "$smartStatus"},
		{"title" : "Last Jamf Checkin:", "icon" : "https://resources.jamf.com/images/logos/Jamf-Icon-color.png",  "status" : "${jamf_checkin_icon}", "statustext" : "$last_check_in_time"},
		{"title" : "Last Reboot:", "icon" : "https://use2.ics.services.jamfcloud.com/icon/hash_5d46c28310a0730f80d84afbfc5889bc4af8a590704bb9c41b87fc09679d3ebd", "status" : "${last_reboot_icon}", "statustext" : "$last_reboot_formatted"},
		{"title" : "Battery Condition:","icon" : "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/ToolbarInfo.icns",  "status" : "${batteryStatusIcon}", "statustext" : "$battery_condition"},
		{"title" : "Battery Cycle Count:", "icon" : "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/ToolbarInfo.icns", "status" : "${battery_cycle_icon}", "statustext" : "$battery_cycle"},
		{"title" : "Encryption Status:", "icon" : "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/FileVaultIcon.icns", "status" : "${fvstatus_icon}", "statustext" : "$fvstatus"},
		{"title" : "Crowdstrike Falcon:", "icon" : "/Applications/Falcon.app/Contents/Resources/AppIcon.icns", "status" : "${falcon_connect_icon}", "statustext" : "$falcon_connect_status"}

	]
}
EOF

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Display in Swift Dialog Box
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
	
/usr/local/bin/dialog --message none --progress 0 --progresstext "Select the help menu for results explanations." --icon $logo --height 800 --title "Computer Health Check" --moveable --jsonfile /tmp/dialogjson.json --infobox "Current User: $loggedInUser\n \nComputer Model: $computerModel \n \n CPU: $cpu \n \n Useable Storage: $total_storage \n\nRAM: $ramsize GB\n \n macOS Version: $sw_vers \n\n Update Status: $updateStatus\n\n Last macOS Update: $lastUpdateDate\n\n Computer Name: $computerName \n\nSerial Number: $serialNumber" --button1Text "Exit" --infobutton --infobuttontext "Get Help" --infobuttonaction "https://fanatics.service-now.com/fanatics" --helpmessage "Free Disk Space must be above 50GB available.\n\n SMART Status must return 'Verified'.\n\n Last Jamf Checkin must be within 7 days.\n\n Last Reboot must be within 14 days.\n\n Battery Condition must return 'Normal'.\n\n Battery Cycle Count must be below 1000. \n\n Encryption status must return 'Filevault is on'.\n\n Crowdstrike Falcon must be connected.\n\n macOS must be on version $macOSversion2 or $macOSversion1" 

if [[ -f /tmp/dialogjson.json ]]; then
	updateScriptLog "json file found, deleting"
	rm /tmp/dialogjson.json
	updateScriptLog "removed json file"
fi
exit 0