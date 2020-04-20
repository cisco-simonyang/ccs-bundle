$drive=(get-location).Drive.Name

. "${drive}:\agentenv.ps1"
echo 'Executing Agent-lite installation script'

$SERVICE_NAME = "AgentService"

$service = Get-Service | Where-Object { $_.Name -eq $SERVICE_NAME }
if ( $service -ne $null ) {
    Write-Host "$SERVICE_NAME already installed"
    exit
}

##############################
# ZIP Utility Alias
##############################
function Expand-ZIPFile($file, $destination)
{
        $shell = new-object -com shell.application
        $zip = $shell.NameSpace($file)
        foreach($item in $zip.items())
        {
                $shell.Namespace($destination).copyhere($item,0x14)
        }
}

If ($NODE_ID -eq $null){
    echo "Variable NODE_ID not available in the env file"
    exit -1
}

If ($CLOUD_FAMILY -eq $null){
    echo "Variable CLOUD_FAMILY not available in the env file"
    exit -1
}

If ($RABBIT_IP -eq $null){
    echo "Variable RABBIT_IP not available in the env file"
    exit -1
}

If ($RABBIT_PORT -eq $null){
    echo "Variable RABBIT_PORT not available in the env file"
    exit -1
}

If ($PKG_URL -eq $null){
    echo "Variable PKG_URL not available in the env file"
    exit -1
}

If ($VHOST -eq $null){
    echo "Variable VHOST not available in the env file"
    exit -1
}

$PKG_NAME = "agent-lite-windows-bundle.zip"
$destDir = "${drive}:\temp"
If (!(Test-Path $destDir)) {
   New-Item -Path $destDir -ItemType Directory
}
cd $destDir
$PKG_PATH = "$destDir\$PKG_NAME"

if (![string]::IsNullOrEmpty($buildCredential)) {
   Invoke-Expression $buildCredential
}
Invoke-Expression "Invoke-WebRequest $credential -Uri $PKG_URL -OutFile $PKG_NAME"

if(![System.IO.File]::Exists($PKG_PATH)){
    echo "Failed to download package $PKG_NAME from URL $PKG_URL"
    exit -1
}

$targetDir = "${drive}:\opt"
If (!(Test-Path $targetDir)) {
   New-Item -Path $targetDir -ItemType Directory
}

#Starting from Powershell version 5 (Win 2016), there is an inbuilt command to extract archives.
#The custom approach as defined in Exapand-ZIPFIle fails Version 5+ onwards due to COM exception for the line:
#$shell = new-object -com shell.application.
#So try to use the Expand-Archive command, and if that fails use the custom extracter code
Try{
    Write-Host "Use Expand-Archive powershell command to extract $PKG_PATH..."
    Expand-Archive -Path "$PKG_PATH" -DestinationPath "$targetDir" -Force
}Catch{
    Write-Host "Failed to extract archive using Expand-Archive command"
    Write-Host "Use custom archive decompression utility to extract $PKG_PATH..."
    Expand-ZIPFile -File "$PKG_PATH" -Destination "$targetDir"

}

Write-Host "Archive extracted in directory $targetDir"
$AGENT_HOME = "$targetDir\agentlite"
If (!(Test-Path $AGENT_HOME)) {
   echo "Failed to extract the file $PKG_PATH"
   exit -1
}

$CONFIG_FILE = "$AGENT_HOME\config\config.json"

Get-Content "$AGENT_HOME\config\config.template.json" | %{$_ -creplace '\%AMQP_HOST\%', $RABBIT_IP} | %{$_ -creplace '\%AMQP_PORT\%', $RABBIT_PORT} | %{$_ -creplace '\%CLOUD_FAMILY\%', $CLOUD_FAMILY} | %{$_ -creplace '%NODE_ID%', $NODE_ID } | %{$_ -creplace '\%VHOST\%', $VHOST} | Set-Content "$CONFIG_FILE"

if(![System.IO.File]::Exists($CONFIG_FILE)){
    echo "Failed to copy config file $CONFIG_FILE from $AGENT_HOME\config\config.template.json"
    exit -1
}

#Installation
$AGENT_EXE = "$AGENT_HOME\bin\agent-lite.exe"
$AGENT_LOG = "$AGENT_HOME\log"
$PRSRV = "$AGENT_HOME\utils\prunsrv.exe"

cmd /c $PRSRV //IS/$SERVICE_NAME `
    --DisplayName=$SERVICE_NAME `
    --Install=$PRSRV `
    --Startup=auto `
    --StartMode=exe `
    --StartImage=$AGENT_EXE `
    --StartPath=$AGENT_HOME `
    --StartParams="-configFile=$CONFIG_FILE;-logFile=$AGENT_LOG\agent.log;-logLevel=DEBUG" `
    --LogPath=$AGENT_LOG `
    --LogLevel=Debug `
    --LogPrefix=agent-startup

if (!$?) {
    throw "Failed to install $SERVICE_NAME. Refer to log in $AGENT_LOG"
    exit
}

#Start
Start-Service $SERVICE_NAME
if (!$?) {
    throw "Failed to start $SERVICE_NAME. Refer to log in $AGENT_LOG"
    exit
}

echo "Done"



