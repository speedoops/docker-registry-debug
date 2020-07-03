#region: Workaround for SelfSigned Cert an force TLS 1.2
$Source = @"
using System.Net;
using System.Security.Cryptography.X509Certificates;
public class TrustAllCertsPolicy : ICertificatePolicy {
    public bool CheckValidationResult(
        ServicePoint srvPoint, X509Certificate certificate,
        WebRequest request, int certificateProblem) {
        return true;
    }
}
"@
Add-Type -TypeDefinition $Source

[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
[System.Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
#endregion
#https://blog.ukotic.net/2017/08/15/could-not-establish-trust-relationship-for-the-ssltls-invoke-webrequest/

#powershell dockerless docker-image downloader on limited networks
#2019.03
param($image,$tag)
if ($image.length -eq 0) {
    $image="ubuntu"
}
if ($tag.length -eq 0) {
    $tag="latest"
}

$imageuri = "https://auth.docker.io/token?service=registry.docker.io&scope=repository:library/"+$image+":pull"
$taguri = "https://hub-mirror.c.163.com/v2/library/"+$image+"/manifests/"+$tag
$bloburi = "https://hub-mirror.c.163.com/v2/library/"+$image+"/blobs/sha256:"

#houskeeping
rm *.gz

#ntlm auth
#$browser = New-Object System.Net.WebClient
#$browser.Proxy.Credentials =[System.Net.CredentialCache]::DefaultNetworkCredentials

#token request
$token = Invoke-WebRequest -Uri $imageuri | ConvertFrom-Json | Select -expand token
echo token: $token

#pull image manifest
$blobs = $($(Invoke-Webrequest -Headers @{Authorization="Bearer $token"} -Method GET -Uri $taguri | ConvertFrom-Json | Select -expand fsLayers ) -replace "sha256:" -replace "@{blobSum=" -replace "}")

#download blobs
for ($i=0; $i -lt $blobs.length; $i++) {
    $blobelement =$blobs[$i]
   
    Invoke-Webrequest -Headers @{Authorization="Bearer $token"} -Method GET -Uri $bloburi$blobelement -OutFile blobtmp
    
    $source = "blobtmp"
    $newfile = "$blobelement.gz"

    #bug : not overwrite
    Rename-Item $source -NewName $newfile -Force

    #overwrite
    #Copy-Item $source $newfile -Force -Recurse
    
    #source blobs
    ls *.gz
}

#postprocess
echo "copy these .gz to your docker machine"
echo "docker import .gz backward"
echo "lastone with $image:$tag"
echo "after docker export and reimport to make a simple layer image"
pause
