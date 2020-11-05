function fileRetention($filepath){
    if ((Get-ChildItem -path $filepath).Length -gt 5242880) {
        Remove-Item -Path $filepath
    }
}

$Global:srcPath = split-path -path $MyInvocation.MyCommand.Definition 
$Global:mainPath = split-path -path $srcPath
$Global:root = split-path -path $mainPath
$Global:resourcespath = join-path -path "$mainPath" -ChildPath "resources"
$Global:errorVariable = "Stop"
$Global:logFile = "$resourcespath\processing.log"

Import-Module -Force "$resourcespath\PolarAuthentication.psm1"

"$(Get-Date) [Processing] Start--------------------------" >> $Global:logFile

#Requirements Check
if (($psversiontable.psversion.Major -lt 5)) {
    "$(Get-Date) [RequirementsCheck] Please Install Powershell 5, Link: https://www.microsoft.com/en-us/download/details.aspx?id=54616" >> $Global:logFile
    Write-Error -Message "Please Install Powershell Core Version 5, Link: https://www.microsoft.com/en-us/download/details.aspx?id=54616" -ErrorAction Stop
}

$callBackPort = 5000
$callBackEndpoint = "/oauth2_callback"
$redirectUrl = "http://localhost:{0}{1}" -f $callBackPort, $callBackEndpoint

$polarAuthentication = Get-PolarAuthentication $redirectUrl
$polarAuthentication.getPolarAuthenticationIdandSecret("$resourcespath\PolarAuth.xml")
$polarAuthentication.getAuthorizationUrl()
$polarAuthentication.getAuthCode()

fileRetention $Global:logFile