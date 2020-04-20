param (
 [string]$CloudType = "{CLOUDTYPE}",
 [string]$CloudRegion = "{CLOUDREGION}",
 [string]$BundleStoreUrl = "{BUNDLE_STORE_URL}",
 [string]$isAgentFlavorLite = "{IS_AGENT_FLAVOR_LITE}"
 )

$SYSTEM_DRIVE = (Get-WmiObject Win32_OperatingSystem).SystemDrive
$BOOTSTRAP_INIT_LOG_FILE="$SYSTEM_DRIVE\bootstrap-init.log"

#Writes to Log file and also echoes it to standard output
Function WriteToBootstrapLog([string] $logstring)
{
	Add-content $BOOTSTRAP_INIT_LOG_FILE -value "[$(Get-Date)] $logstring"
	Write-Host "$string"
}

WriteToBootstrapLog "Trim any trailing / from Bundle URL: $BundleStoreUrl ..."
$BundleStoreUrl = $BundleStoreUrl.TrimEnd('/')

WriteToBootstrapLog "Set Environment var: BUNDLE_STORE_URL = $BundleStoreUrl"
[Environment]::SetEnvironmentVariable('BUNDLE_STORE_URL', "$BundleStoreUrl", 'Machine')
WriteToBootstrapLog "Set Environment var: IS_AGENT_FLAVOR_LITE = $isAgentFlavorLite"
[Environment]::SetEnvironmentVariable('IS_AGENT_FLAVOR_LITE', "$isAgentFlavorLite", 'Machine')

Function DownloadFile($Url, $TargetPath, $wait)
{
	$clnt = New-Object System.Net.WebClient
	$bundleStoreCredentialFile = "$SYSTEM_DRIVE\temp\bundleStoreCredential"
	if (Test-Path $bundleStoreCredentialFile) {
		$bundleStoreCredential = ConvertFrom-Json -InputObject (gc $bundleStoreCredentialFile)
		$clnt.Credentials = New-Object System.Net.Networkcredential($bundleStoreCredential.bundleStoreUser, $bundleStoreCredential.bundleStorePassword)
	}
	$FileName = [System.IO.Path]::GetFileName($Url)
	$TargetFileName = Join-Path $TargetPath $FileName
	$Failed=1

	if ($wait -eq "true"){
		do {
			try {
				$clnt.DownloadFile($Url, $TargetFileName)
				$Failed=0
			} catch [System.Net.WebException] {
				WriteToBootstrapLog "Error downloading: $_.Exception.Message"
				WriteToBootstrapLog "Retry..."
			}
		} while ($Failed -gt 0)
	}else{
		try {
			$clnt.DownloadFile($Url, $TargetFileName)
		} catch [System.Net.WebException] {
			WriteToBootstrapLog "Error downloading: $_.Exception.Message. Return empty value."
			return ""
		}
	}
	return $TargetFileName

}

#{bundleStoreCredential}

if (-not (Test-Path "$SYSTEM_DRIVE\Program Files\osmosix"))
{
	if (-not (Test-Path "$SYSTEM_DRIVE\Temp")){
		$Temp = "$SYSTEM_DRIVE\Temp"
		New-Item -ItemType Directory -Force -Path $Temp
		WriteToBootstrapLog "Created $SYSTEM_DRIVE\Temp"
	}else{
		WriteToBootstrapLog "$SYSTEM_DRIVE\Temp is already created"
	}

	$Temp = "$SYSTEM_DRIVE\Temp"

	$BootstrapMetadataExtractorURL="$BundleStoreUrl/metadata_extractor.ps1"
	#$BootstrapMetadataExtractorURL="http://env.cliqrtech.com/sudeepta/bundle/4.10.0.4/metadata_extractor.ps1"
	WriteToBootstrapLog "Download $BootstrapMetadataExtractorURL to $Temp directory..."
	$BootstrapMetadataExtractorFile = DownloadFile $BootstrapMetadataExtractorURL $Temp "false"
	if (($BootstrapMetadataExtractorFile) -and (Test-Path $BootstrapMetadataExtractorFile)){
		WriteToBootstrapLog "Execute the downloaded metadata extractor script: $BootstrapMetadataExtractorFile ..."
		. $BootstrapMetadataExtractorFile
		#Add check to see if metadata.out got created
	}else{
		WriteToBootstrapLog "Metadata extraction script not found. Supported clouds will use corresponding implementations to extract metadata."
	}

	$InstallerUrl = "$BundleStoreUrl/cliqr_installer.exe"
	WriteToBootstrapLog "Installer URL: $InstallerUrl"
	$Installer = DownloadFile $InstallerUrl $Temp "true"
	WriteToBootstrapLog "Downloaded Installer to Temp. Start Installer run with cloud type: $CloudType"
	Start-Process -Wait $Installer -ArgumentList "/silent /CLOUDTYPE=$CloudType /CLOUDREGION=default"
	WriteToBootstrapLog "Started process: $Installer"
	Start-Service "CliQrStartupService"
}else{
	WriteToBootstrapLog "Cliqr Installer will not be installed again as C:\Program Files\osmosix exists indicating this is a Custom image."
}
#{cliqrRenameWinHostname}
#{cliqrConfigScript}
#{cliqrJsonInjection}
