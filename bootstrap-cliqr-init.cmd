set BUNDLE_STORE_URL=http://cdn.cliqr.com/release-5.2.2/bundle
set BOOTSTRAP_PS_URL="%BUNDLE_STORE_URL%/bootstrap-cliqr-init.ps1"
set CLOUDREGION="softlayer-region"
if not exist "C:\Temp" mkdir "C:\Temp"

powershell -ExecutionPolicy bypass "Invoke-WebRequest %BOOTSTRAP_PS_URL% -OutFile C:\Temp\bootstrap-cliqr-init.ps1"
powershell -ExecutionPolicy bypass "C:\Temp\bootstrap-cliqr-init.ps1" -CloudType Softlayer -CloudRegion %CLOUDREGION% -BundleStoreUrl %BUNDLE_STORE_URL%
