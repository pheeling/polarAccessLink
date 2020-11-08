function Get-PolarAuthentication([String] $redirectUrl){
    return [PolarAuthentication]::new($redirectUrl)
}

class PolarAuthentication {

    $polarAuth
    $clientID 
    $clientSecret
    $redirectUrl
    $authorizationUrl = "https://flow.polar.com/oauth2/authorization"
    $accessTokenUrl = "https://polarremote.com/v2/oauth2/token"
    $accessLinkUrl = "https://www.polaraccesslink.com/v3"
    $authorizationCode
    $tokenresponse

    PolarAuthentication($redirectUrl){
        $this.redirectUrl = $redirectUrl
    }

    getPolarAuthenticationIdandSecret($path){
        $this.polarAuth = Import-Clixml -path $path
    }

    getAuthorizationUrl(){

        $this.clientID = [System.Web.HttpUtility]::UrlEncode($this.polarAuth.GetNetworkCredential().Username)
        $this.clientSecret = [System.Web.HttpUtility]::UrlEncode($this.polarAuth.GetNetworkCredential().Password)
        $this.authorizationUrl = "$($this.authorizationUrl)?response_type=code&client_id=$($this.clientID)"
        
        #$response = Invoke-WebRequest -Uri $this.authorizationUrl -Method Get -ContentType "application/x-www-form-urlencoded" -Headers $params -ErrorAction "Stop"
       
    }

    getAuthCode(){
        $authCodeRegex = '(?<=code=)(.*)'
        $ie = New-Object -com InternetExplorer.Application
        $ie.navigate2($this.authorizationUrl)
        $ie.Visible=$true
        Start-Sleep 5
        $Shell = New-Object -com "Shell.Application"
        $result = $shell.Windows() | Select-Object locationname
        $url = ($result | Where-Object {$_ -match "(https?://.+)"}).locationname
        if ($url -match "error=[^&]*"){
            #$ie.quit()
            Write-Error "Error happen while authentication, please check your setup"
        } elseif($url -eq "" ) {
            Write-Error "Connection Closed before hitting this point, please check your setup"
        } elseif($url.count -gt 1) {
            Write-Error "too many IE open close old windows"
        } else {
            # Extract Access token from the returned URI.
            $url | Where-Object {$_ -match $authCodeRegex}
            $authCode = $Matches[0]

            $base64IdSecret = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes("$($this.clientID):$($this.clientSecret)"))            
            # Get Access Token.
            #TODO: invalid Client Error maybe because authentication needs headers
            $HeaderParams = @{
                "Content-Type" = "application/x-www-form-urlencoded"
                "Accept" = "application/json;charset=UTF-8"
                "Authorization" = "Basic $base64IdSecret"
            }

            $Body = "grant_type=authorization_code&code=$authCode"

            $this.tokenresponse = Invoke-RestMethod $this.accessTokenUrl -Method Post `
            -Body $Body -Headers $HeaderParams -ErrorAction "Stop"

            $this.tokenresponse.access_token
        }

        
    }
}