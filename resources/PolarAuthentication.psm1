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

        $this.clientId = [System.Web.HttpUtility]::UrlEncode($this.polarAuth.GetNetworkCredential().Username)
        $this.authorizationUrl = "$($this.authorizationUrl)?response_type=code&client_id=$($this.clientID)"
        
        #$response = Invoke-WebRequest -Uri $this.authorizationUrl -Method Get -ContentType "application/x-www-form-urlencoded" -Headers $params -ErrorAction "Stop"
       
    }

    getAuthCode(){
        $authCodeRegex = '(?<=code=)(.*)'
        $ie = New-Object -com InternetExplorer.Application
        $ie.navigate2($this.authorizationUrl)
        $ie.Visible=$true
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
            
            # Get Access Token.
            $Body = "grant_type=authorization_code&code=$authCode"
            $this.tokenresponse = Invoke-RestMethod $this.accessTokenUrl -Method Post -ContentType "application/x-www-form-urlencoded" -Body $Body -ErrorAction "Stop"

            $this.tokenresponse.access_token
        }

        
    }

    <# getAuthCode(){
        Add-Type -AssemblyName System.Windows.Forms
        $Form = New-Object -TypeName System.Windows.Forms.Form -Property @{Width = 440; Height = 640 }
        $Web = New-Object -TypeName System.Windows.Forms.WebBrowser -Property @{
            Width = 420; Height = 600; Url = $this.authorizationUrl  }
        $DocComp = {
            $Global:uri = $Web.Url.AbsoluteUri        
            if ($Global:uri -match "error=[^&]*|code=[^&]*") { $Form.Close() }
        }

        $Web.ScriptErrorsSuppressed = $true
        $Web.Add_DocumentCompleted($DocComp)
        $Form.Controls.Add($Web)
        $Form.Add_Shown( { $Form.Activate() })
        $Form.ShowDialog() | Out-Null
        $QueryOutput = [System.Web.HttpUtility]::ParseQueryString($Web.Url.Query)
        $Output = @{ }

        foreach ($Key in $QueryOutput.Keys) {
            $Output["$Key"] = $QueryOutput[$Key]
        }

        # Extract Access token from the returned URI.
        $regex = '(?<=code=)(.*)(?=&)'
        $authCode = ($Global:uri | Select-string -pattern $regex).Matches[0].Value

         # Get Access Token.
        $Body = "grant_type=authorization_code&code=$authCode"
        $this.tokenresponse = Invoke-RestMethod $this.accessTokenUrl -Method Post -ContentType "application/x-www-form-urlencoded" -Body $Body -ErrorAction "Stop"

        $this.tokenresponse.access_token
    } #>
}