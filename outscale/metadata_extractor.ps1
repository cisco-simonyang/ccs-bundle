#Do not change the output file path
$METADATA_FILE="C:\Temp\metadata.out"
 
#Define your cloud specific commands to retrieve node metadata
$instId="http://169.254.169.254/latest/meta-data/instance-id"
$instType="http://169.254.169.254/latest/meta-data/instance-type"
$privIP="http://169.254.169.254/latest/meta-data/local-ipv4"
$pubIP="http://169.254.169.254/latest/meta-data/public-ipv4"
$hostname="http://169.254.169.254/latest/meta-data/hostname"
$amiId="http://169.254.169.254/latest/meta-data/ami-id"
 
$response = Invoke-WebRequest $instId -UseBasicParsing
if(($response.StatusCode -lt 200) -or ($resonse.StatusCode -ge 300)) {
    Write-Host "Failed to get information from: $instId"
}else{
    Write-Host $response.Content
    Add-Content $METADATA_FILE "INSTANCE_ID=$response,"
}
 
$response = Invoke-WebRequest $instType -UseBasicParsing
if(($response.StatusCode -lt 200) -or ($resonse.StatusCode -ge 300)) {
    Write-Host "Failed to get information from: $instType"
}else{
    Write-Host $response.Content
    Add-Content $METADATA_FILE "INSTANCE_TYPE=$response,"
}
 
$response = Invoke-WebRequest $privIP -UseBasicParsing
if(($response.StatusCode -lt 200) -or ($resonse.StatusCode -ge 300)) {
    Write-Host "Failed to get information from: $privIP"
}else{
    Write-Host $response.Content
    Add-Content $METADATA_FILE "PRIVATE_IP=$response,"
}
 
$response = Invoke-WebRequest $pubIP -UseBasicParsing
if(($response.StatusCode -lt 200) -or ($resonse.StatusCode -ge 300)) {
    Write-Host "Failed to get information from: $pubIP"
}else{
    Write-Host $response.Content
    Add-Content $METADATA_FILE "PUBLIC_IP=$response,"
}
 
$response = Invoke-WebRequest $hostname -UseBasicParsing
if(($response.StatusCode -lt 200) -or ($resonse.StatusCode -ge 300)) {
    Write-Host "Failed to get information from: $hostname"
}else{
    Write-Host $response.Content
    Add-Content $METADATA_FILE "HOSTNAME=$response,"
}
 
$response = Invoke-WebRequest $amiId -UseBasicParsing
if(($response.StatusCode -lt 200) -or ($resonse.StatusCode -ge 300)) {
    Write-Host "Failed to get information from: $amiId"
}else{
    Write-Host $response.Content
    Add-Content $METADATA_FILE "AMID_ID=$response,"
}
