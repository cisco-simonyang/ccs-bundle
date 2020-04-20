#########################################################################
#	Windows Worker Bootstrap Script
#
#   Note: Please do NOT remove duplicated variables, and when you update
#         any of the variables, you update them all.
#	Copyright(c) 2013 CliQr Technologies, Inc., all rights reserved.
#########################################################################

param (
   [string]$action = "install",
   [string]$exec_id = 0,
   [string]$cloud_unique_resource_id = 0,
   [string]$agent_flavor_lite_upgrade = "false",
   [string]$bundle_source_url = 0
)

. 'c:\Program Files\osmosix\etc\cliqr.ps1'

$BOOTSTRAP_WORKER_LOG_FILE = "C:\bootstrap-worker.log"
#Writes to Log file and also echoes it to standard output
function WriteToBootstrapWorkerLog([string] $logstring)
{
    Add-content $BOOTSTRAP_WORKER_LOG_FILE -value "[$( Get-Date )] $logstring"
    Write-Host "$string"
}

#NOTE: It is repeated here although we source cliqr.ps1, because certain custom images have older cliqr.ps1
#Compatible method for Powershell V2.0 since only V3.0 has isNullOrWhiteSpace method for String
function StringIsNullOrWhitespace([string] $string)
{
    if ($string -ne $null) {
        $string = $string.Trim()
    }
    return [string]::IsNullOrEmpty($string)
}

WriteToBootstrapWorkerLog "Checking for sysprep folder invoked from bootstrap-cliqr-worker.ps1"
$sysprepPath = "C:\sysprep"
$sysprepFlagFile = "C:\temp\.sysprepdone"
$sysprepfoldercontents = Join-Path $sysprepPath "*"

#This check is applicable only for vmware clouds
if ((Test-Path $sysprepPath) -and ($OSMOSIX_CLOUD -eq "vmware")) {

    if ([System.Environment]::OSVersion.Version.Major -ge 10) {
        WriteToBootstrapWorkerLog "Detected OS is Windows Server 2016"
    }
    if ([System.Environment]::OSVersion.Version.Major -le 6) {
        if (	[System.Environment]::OSVersion.Version.Minor -ge 3) {
            WriteToBootstrapWorkerLog "Detected OS is Windows Server 2012"
        } else {
            WriteToBootstrapWorkerLog "Detected OS is Windows Server 2008/2008R2"
        }
    }

    if (-not(Test-Path $sysprepfoldercontents)) {
        # Happens when vmware fails to delete the folder c:\sysprep after sysprep is completed
        WriteToBootstrapWorkerLog "Sysprep Folder present but its empty"
        WriteToBootstrapWorkerLog "Continue to Agent bundle download."
    } else {
        WriteToBootstrapWorkerLog "Sysprep Folder present and contents not empty."
        WriteToBootstrapWorkerLog "Exiting bootstrap"
        exit

    }

}

$BUNDLE_STORE_URL=[Environment]::GetEnvironmentVariable('BUNDLE_STORE_URL', 'Machine')
$OSMOSIX_INSTALL_DIR = 'c:\Program Files'
#C:\Program Files\cliqrstage
$CLIQR_STAGE_DIR= "{0}\cliqrstage" -f $OSMOSIX_INSTALL_DIR
#C:\Program Files\osmosix\AGENTINSTALLED
$AGENT_INSTALLED_FILE = "{0}\AGENTINSTALLED" -f $OSMOSIX_CONF_HOME
#$AGENT_BUNDLE_PROP = 'agentBundleURL'

$userData = $OSMOSIX_SYSTEM_DATA
WriteToBootstrapWorkerLog "User Data: '$userData'"

#Load userdata as JSON
[Reflection.Assembly]::LoadFile("C:\Program Files\osmosix\lib\Newtonsoft.Json.dll")
$userDataJSON = [Newtonsoft.Json.Linq.JObject]::Parse($userData)
WriteToBootstrapWorkerLog "User Data JSON: '$userDataJSON'"

#Parse userdata to get agent flavor flag value. If Upgrade mode, then use the user input to decide agent flavor
$isAgentFlavorLite = $userDataJSON.Item("agentFlavorLite").ToString()
WriteToBootstrapWorkerLog "Agent Flavor Lite from user-data: '$isAgentFlavorLite'"
if ($action -eq "upgrade") {
    WriteToBootstrapWorkerLog "Action mode is 'upgrade'. Will agent be upgraded with agent-lite ? : '$agent_flavor_lite_upgrade'"
    $isAgentFlavorLite = $agent_flavor_lite_upgrade
    WriteToBootstrapWorkerLog "Agent Flavor Lite value as per user input for upgrade : '$isAgentFlavorLite'"
}

#Get Bundle URL from env. If empty, then user data is to be used
WriteToBootstrapWorkerLog "Agent Bundle Store URL from env param: '$BUNDLE_STORE_URL'"
$AGENT_BUNDLE_BASE_URL = "$BUNDLE_STORE_URL"
if (StringIsNullOrWhitespace($BUNDLE_STORE_URL)){
    WriteToBootstrapWorkerLog "Bundle Store URL env param is empty. Extract from user-data..."
    $AGENT_BUNDLE_BASE_URL = $userDataJSON.Item("BundleStoreUrl").ToString()
}

WriteToBootstrapWorkerLog "Agent action: '$action'"
#If the Action is upgrade and the upgrade URL is passed, only then use it as the Agent Bundle Base URL
if (($action -eq "upgrade") -and ($bundle_source_url)) {
	WriteToBootstrapWorkerLog "Action Mode is 'upgrade' with input Bundle store URL provided as : '$bundle_source_url' "
	$AGENT_BUNDLE_BASE_URL = "$bundle_source_url"
}

$AGENT_BUNDLE_FILE = 'osmosix-agent-@project.version@-windows-worker-bundle.tar.gz'

if ($isAgentFlavorLite -eq "true") {
    $AGENT_BUNDLE_FILE = 'agent-lite-windows-bundle.zip'
    WriteToBootstrapWorkerLog "Golang agent will be installed"
}

WriteToBootstrapWorkerLog "Agent Bundle Base URL: $AGENT_BUNDLE_BASE_URL and Agent Bundle File: $AGENT_BUNDLE_FILE"
$AGENT_BUNDLE_URL = "{0}/{1}" -f $AGENT_BUNDLE_BASE_URL, $AGENT_BUNDLE_FILE
WriteToBootstrapWorkerLog "Agent Bundle URL: '$AGENT_BUNDLE_URL'"

WriteToBootstrapWorkerLog "Starting bootstrap-cliqr-worker..."

if ((Test-Path $AGENT_INSTALLED_FILE) -and ($action -ne "upgrade")) {
	WriteToBootstrapWorkerLog "Agent bundle already deployed."
} else {

    $client = New-Object System.Net.WebClient
    if ($OSMOSIX_CREDENTIAL_REQUIRED) {
	    $client.Credentials = New-Object System.Net.Networkcredential($OSMOSIX_BOOTSTRAP_USERNAME, $OSMOSIX_BOOTSTRAP_PASSWORD)
    }

	if (Test-Path $AGENT_INSTALLED_FILE -PathType Container ) {
        WriteToBootstrapWorkerLog "Delete $AGENT_INSTALLED_FILE file "
		rm -r $AGENT_INSTALLED_FILE
	}

    $AGENT_BUNDLE_TEMP_PATH = 'c:\temp'
    $AGENT_BUNDLE_DOWNLOAD_FLAG_FILE = 'c:\temp\downloaded'
    $target = "{0}\{1}" -f $AGENT_BUNDLE_TEMP_PATH, $AGENT_BUNDLE_FILE

    #Delete the agent bundle downloaded marker if found
    if (Test-Path $AGENT_BUNDLE_DOWNLOAD_FLAG_FILE ) {
        WriteToBootstrapWorkerLog "Delete $AGENT_BUNDLE_DOWNLOAD_FLAG_FILE file "
        rm -r $AGENT_BUNDLE_DOWNLOAD_FLAG_FILE
    }

    WriteToBootstrapWorkerLog "Downloading agent bundle $AGENT_BUNDLE_URL to $target"

	for ($i = 0; $i -lt 10; ++$i) {
		try {
            WriteToBootstrapWorkerLog "Downloading agent bundle; attempt number: $i"
			$client.DownloadFile($AGENT_BUNDLE_URL, $target)
			echo "" > $AGENT_BUNDLE_DOWNLOAD_FLAG_FILE
			break
		} catch [System.Exception] {
            WriteToBootstrapWorkerLog "Error trying to download. Sleep for 10 seconds and retry till maximum retry limit of 10 is not reached"
			sleep 10
		}
	}

	if (Test-Path $AGENT_BUNDLE_DOWNLOAD_FLAG_FILE) {
		WriteToBootstrapWorkerLog "Agent bundle download completed"
	} else {
		WriteToBootstrapWorkerLog "Agent bundle download timeout"
	}

	if (Test-Path $target) {
		WriteToBootstrapWorkerLog "Agent bundle downloaded successfully"
	} else {
		WriteToBootstrapWorkerLog "Failed to download agent bundle, program exiting now"
		$host.SetShouldExit(1)
		return
	}

	WriteToBootstrapWorkerLog "Extracting agent bundle..."
    if ($isAgentFlavorLite -eq "true") {
        $SYSTEM_DRIVE = (Get-WmiObject Win32_OperatingSystem).SystemDrive

        #C:\opt
        $AGENTGO_PARENT_DIR = "$SYSTEM_DRIVE\opt"
        $AGENTGO_STAGE_PARENT_DIR="$SYSTEM_DRIVE\opt\cliqrstage"

        WriteToBootstrapWorkerLog "Check if AgentGo Parent directory exists. If not create it: '$AGENTGO_PARENT_DIR'"
        if (-not (Test-Path $AGENTGO_PARENT_DIR)) {
            WriteToBootstrapWorkerLog "Create $AGENTGO_PARENT_DIR..."
            mkdir $AGENTGO_PARENT_DIR
        }
        else {
            WriteToBootstrapWorkerLog "$AGENTGO_PARENT_DIR already exists."
        }

        #This is to be done because although Agentlite does not finally land in C:\Program Files\cliqrstage directory,
        #We still have logs that are written there. And Java Agent backup happens there in case of Upgrade
        #Also the c3upgrade.log is written in this place. So this is like the Link between java agent and Go agent
        #TODO In Next release remove usage of this directory or when Java agent support is completely removed
        WriteToBootstrapWorkerLog "Check if Cliqr Stage directory exists. If not create it: '$CLIQR_STAGE_DIR'"
        if (-not (Test-Path $CLIQR_STAGE_DIR)) {
            WriteToBootstrapWorkerLog "Create $CLIQR_STAGE_DIR..."
            mkdir $CLIQR_STAGE_DIR
        }
        else {
            WriteToBootstrapWorkerLog "Delete and recreate $CLIQR_STAGE_DIR"
            rm -force -recurse $CLIQR_STAGE_DIR
            mkdir $CLIQR_STAGE_DIR
        }

        #In Upgrade Mode, we will be installing Golang agent after removing existing agent.
        #So copy it to AgentGo Staging directory
        if ($action -eq "upgrade") {
            WriteToBootstrapWorkerLog "In Upgrade mode, the agent is copied to the directory $AGENTGO_STAGE_PARENT_DIR ..."
            if (-not (Test-Path $AGENTGO_STAGE_PARENT_DIR)) {
                WriteToBootstrapWorkerLog "Create $AGENTGO_STAGE_PARENT_DIR..."
                mkdir $AGENTGO_STAGE_PARENT_DIR
            }
            else {
                WriteToBootstrapWorkerLog "Cleanup any previous agentlite directory in $AGENTGO_STAGE_PARENT_DIR if it exists..."
                if (Test-Path $AGENTGO_STAGE_PARENT_DIR\agentlite){
                    WriteToBootstrapWorkerLog "Delete $AGENTGO_STAGE_PARENT_DIR\agentlite..."
                    rm -force -recurse $AGENTGO_STAGE_PARENT_DIR\agentlite
                }
            }
            WriteToBootstrapWorkerLog "Set the directory to copy the agent bundle as $AGENTGO_STAGE_PARENT_DIR"
            $AGENTGO_PARENT_DIR = $AGENTGO_STAGE_PARENT_DIR
        }

        WriteToBootstrapWorkerLog "Agent Parent Directory: $AGENTGO_PARENT_DIR"


        ################################ DOWNLOAD UNARCHIVER FOR OLDER IMAGES ############################################
        # Copy Bundled Unarchiver App to standard Location if it does not exist there.
        # This step has to be done to support older Custom Images which were built using older cliqr_installer.exe
        # This is also being done in install.ps1 but was added there in 5.1. So Upgrade of older image based
        # workers (which have pre-5.1 agents, will still hit the issue of not finding ccc_unarchiver.exe
        $WORKER_UNARCHIVER_EXE = "C:\opt\zip\ccc_unarchiver.exe"
        $TEMP_WORKER_UNARCHIVER_EXE = "C:\Temp\ccc_unarchiver.exe"
        if ((-not (Test-Path $WORKER_UNARCHIVER_EXE))){
            WriteToBootstrapWorkerLog "Unarchiver App is not present on worker at $WORKER_UNARCHIVER_EXE. Download it from Bundle Repo..."

            $UNARCHIVER_BUNDLE_URL = "{0}/{1}" -f $AGENT_BUNDLE_BASE_URL, "ccc_unarchiver.exe"
            WriteToBootstrapWorkerLog "Unarchiver Bundle URL: '$UNARCHIVER_BUNDLE_URL'"
            WriteToBootstrapWorkerLog "Downloading unarchiver app $UNARCHIVER_BUNDLE_URL to $TEMP_WORKER_UNARCHIVER_EXE ..."

            $client = New-Object System.Net.WebClient
            if ($OSMOSIX_CREDENTIAL_REQUIRED) {
                $client.Credentials = New-Object System.Net.Networkcredential($OSMOSIX_BOOTSTRAP_USERNAME, $OSMOSIX_BOOTSTRAP_PASSWORD)
            }
            for ($i = 0; $i -lt 10; ++$i) {
                try {
                    WriteToBootstrapWorkerLog "Downloading unarchiver app. Attempt number: $i"
                    $client.DownloadFile($UNARCHIVER_BUNDLE_URL, $TEMP_WORKER_UNARCHIVER_EXE)
                    break
                } catch [System.Exception] {
                    WriteToBootstrapWorkerLog "Error trying to download unarchiver app. Sleep for 10 seconds and retry till maximum retry limit of 10 is not reached"
                    sleep 10
                }
            }
        
            if (!(Test-Path $TEMP_WORKER_UNARCHIVER_EXE)) {
                WriteToBootstrapWorkerLog "Failed to download unarchiver. Program exiting now..."
                $host.SetShouldExit(1)
                return
            }

            WriteToBootstrapWorkerLog "Unarchiver downloaded. Create directory structure: C:\opt\zip ..."
            if (!(Test-Path "C:\opt")){
                WriteToBootstrapWorkerLog "Creating directory: C:\opt ..."
                New-Item C:\opt -ItemType directory
            }
            if (!(Test-Path "C:\opt\zip")){
                WriteToBootstrapWorkerLog "Creating directory: C:\opt\zip ..."
                New-Item C:\opt\zip -ItemType directory
            }

            WriteToBootstrapWorkerLog "Unarchiver downloaded. Now copy it to location: $WORKER_UNARCHIVER_EXE ..."
            Copy-item -path $TEMP_WORKER_UNARCHIVER_EXE -destination "C:\opt\zip" -force

            if (!(Test-Path $WORKER_UNARCHIVER_EXE)) {
                WriteToBootstrapWorkerLog "Failed to copy unarchiver to: $WORKER_UNARCHIVER_EXE. Exit flow..."
                $host.SetShouldExit(1)
                return
            }
            WriteToBootstrapWorkerLog "Unarchiver App copied to $WORKER_UNARCHIVER_EXE"
        }
        ##########################################################################################################


        #The Untar-file does not check for zip extension so calling Unzip explicitly
        WriteToBootstrapWorkerLog "Unzip the bundle: $target into $AGENTGO_PARENT_DIR..."
        Unzip-File $target $AGENTGO_PARENT_DIR

        $agent_version=(cat $AGENTGO_PARENT_DIR\agentlite\version)
        WriteToBootstrapWorkerLog "Agent version being installed : [$agent_version]"

        #Write the triplet of exec_id:cloud_unique_resource_id:agent_version to C:\Program Files\cliqrstage\agentlite\bin\agentgo_upgrade_input.txt
        $AGENTGO_UPGRADE_INPUT_FILE="{0}\agentlite\bin\agentgo_upgrade_input.txt" -f $AGENTGO_PARENT_DIR
        $CONTENT="{0}:{1}:{2}" -f $exec_id, $cloud_unique_resource_id, $agent_version
        #echo "$CONTENT" > $AGENTGO_UPGRADE_INPUT_FILE
        Add-content $AGENTGO_UPGRADE_INPUT_FILE -value "$CONTENT"
        WriteToBootstrapWorkerLog "Added to file '$AGENTGO_UPGRADE_INPUT_FILE' the following content: '$CONTENT'"
        

        $agentMode = "greenfield"
        $brokerClusterAddresses = $userDataJSON.Item("brokerClusterAddresses").ToString()
        $brokerIp,$brokerPort = $brokerClusterAddresses.split(':')
        $nodeId = "default"
        WriteToBootstrapWorkerLog "$AGENTGO_PARENT_DIR\agentlite\bin\install.ps1 -brokerHost $brokerIp -brokerPort $brokerPort -cloudFamily $OSMOSIX_CLOUD -nodeId $nodeId -agentMode $agentMode -action $action -brokerVHost ''..."

        start-process -filepath "powershell" -argumentlist "-executionpolicy bypass -noninteractive -file `"$AGENTGO_PARENT_DIR\agentlite\bin\install.ps1`" -brokerHost $brokerIp -brokerPort $brokerPort -cloudFamily $OSMOSIX_CLOUD -nodeId $nodeId -agentMode $agentMode -action $action -brokerVHost ''"

    }else{
        if (-not (Test-Path $CLIQR_STAGE_DIR)) {
            mkdir $CLIQR_STAGE_DIR
        }
        else {
            rm -force -recurse $CLIQR_STAGE_DIR
            mkdir $CLIQR_STAGE_DIR
        }
        Untar-File $target $CLIQR_STAGE_DIR

        start-process -filepath "powershell" -argumentlist "-executionpolicy bypass -noninteractive -file `"$CLIQR_STAGE_DIR\c3agent.ps1`" -action $action -exec_id $exec_id -cloud_unique_resource_id $cloud_unique_resource_id -agent_version @project.version@"
    }

    echo ""> $AGENT_INSTALLED_FILE
}
