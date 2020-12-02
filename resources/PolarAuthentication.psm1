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
        $ie.Visible=$true
        $ie.navigate2($this.authorizationUrl)
        Start-Sleep 5
        $Shell = New-Object -com "Shell.Application"
        $result = $shell.Windows() | Select-Object locationname
        $url = ($result | Where-Object {$_ -match "(http?://.+)"}).locationname
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
            #TODO: invalid Client Error because header needs at least host, cookie, content-length parameter
            # check Postman for successfull attempt
            $Body = "grant_type=authorization_code&code=$authCode"
            $HeaderParams = @{
                # by Post Method Content-Type is application/x-www-form-urlencoded when Flag is omitted
                #"Content-Type" = "application/x-www-form-urlencoded"
                #Cookie Headers or User-Agent can not be used within those headers
                "Accept" = "application/json;charset=UTF-8"
                "Authorization" = "Basic $base64IdSecret"
                "Content-Length" = [System.Text.Encoding]::UTF8.GetByteCount($Body)
                "Host" = "polarremote.com"
            } #>


            #TODO: https://docs.microsoft.com/en-us/dotnet/api/system.net.httpwebrequest?view=net-5.0
            # https://stackoverflow.com/questions/5470474/powershell-httpwebrequest-get-method-cookiecontainer-problem
            # https://en.wikipedia.org/wiki/List_of_HTTP_header_fields#Standard_request_fields
            # https://gallery.technet.microsoft.com/scriptcenter/Getting-Cookies-using-3c373c7e
            #TODO: https://stackoverflow.com/questions/36544334/powershell-net-httpclient-add-header

            #TODO: how does a post work?
            Add-Type -AssemblyName System.Net.Http
            $httpClientHandler = New-Object System.Net.Http.HttpClientHandler
            $httpClient = New-Object System.Net.Http.Httpclient $httpClientHandler
            $httpRequest = New-Object System.Net.Http.HttpRequestMessage
            $mediatype = New-Object System.Net.Http.Headers.MediaTypeHeaderValue("application/x-www-form-urlencoded")
            $encoding = New-Object System.Text.UTF8Encoding
            $uri = New-Object System.Uri($this.accessTokenUrl)

            $httpClient.DefaultRequestHeaders.Authorization = `
            New-Object System.Net.Http.Headers.AuthenticationHeaderValue("Basic", $base64IdSecret);
            $httpClient.DefaultRequestHeaders.Host  = "polarremote.com"


            $httpRequest.Content = New-Object System.Net.Http.StringContent($Body,$encoding,$mediatype)
            $httpRequest.Method = "POST"
            #$httpRequest.Headers.Accept = "application/json;charset=UTF-8"
            $httpRequest.RequestUri = $this.accessTokenUrl

            $response = $httpClient.PostAsync($uri, $httpRequest)




            <# $this.tokenresponse = Invoke-RestMethod $this.accessTokenUrl -Method Post `
            -Body $Body -Headers $HeaderParams -TransferEncoding "chunked"`
            -ErrorAction "Stop"
 #>
            

            $this.tokenresponse.access_token
        }

        
    }
}