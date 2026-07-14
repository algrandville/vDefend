<#
.SYNOPSIS
    Exports vCenter VM information with tags to CSV format.

.DESCRIPTION
    Connects to vCenter using environment variables and exports VM information including
    name, IP addresses, and tags organized by category into a CSV file.

.NOTES
    Required Environment Variables:
    - VCENTER_HOST: vCenter server hostname or IP
    - VCENTER_USERNAME: vCenter username
    - VCENTER_PASSWORD: vCenter password

.EXAMPLE
    .\Export-vCenterVMTags.ps1
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$OutputPath = ".\vm_export.csv"
)

$ErrorActionPreference = "Stop"

try {
    Write-Host "Checking environment variables..." -ForegroundColor Cyan

    $vCenterServer = $env:VCENTER_HOST
    $vCenterUsername = $env:VCENTER_USERNAME
    $vCenterPassword = $env:VCENTER_PASSWORD

    if (-not $vCenterServer) {
        $vCenterServer = Read-Host "VCENTER_HOST not set. Enter vCenter server hostname or IP"
    }
    if (-not $vCenterUsername) {
        $vCenterUsername = Read-Host "VCENTER_USERNAME not set. Enter vCenter username"
    }
    if (-not $vCenterPassword) {
        $securePasswordInput = Read-Host "VCENTER_PASSWORD not set. Enter vCenter password" -AsSecureString
        $vCenterPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePasswordInput))
    }

    if (-not $vCenterServer -or -not $vCenterUsername -or -not $vCenterPassword) {
        throw "Missing required vCenter connection information."
    }

    Write-Host "Connecting to vCenter: $vCenterServer" -ForegroundColor Cyan
    
    $securePassword = ConvertTo-SecureString $vCenterPassword -AsPlainText -Force
    $credential = New-Object System.Management.Automation.PSCredential($vCenterUsername, $securePassword)
    
    $null = Connect-VIServer -Server $vCenterServer -Credential $credential -ErrorAction Stop
    
    Write-Host "Connected to vCenter successfully." -ForegroundColor Green
    Write-Host "Retrieving VM information..." -ForegroundColor Cyan
    
    $vms = Get-VM
    Write-Host "Found $($vms.Count) VMs. Processing..." -ForegroundColor Green
    
    $results = @()
    
    foreach ($vm in $vms) {
        Write-Host "Processing: $($vm.Name)" -ForegroundColor Yellow
        
        $vmGuest = Get-VMGuest -VM $vm
        $ipAddresses = ($vmGuest.IPAddress | Where-Object { $_ -match '\d+\.\d+\.\d+\.\d+' }) -join ';'
        
        $tagAssignments = Get-TagAssignment -Entity $vm -ErrorAction SilentlyContinue

        $tagsByCategory = @{
            'region' = ''
            'zone' = ''
            'environment' = ''
            'application' = ''
            'application tier' = ''
            'infrastructure service' = ''
        }
        
        foreach ($tagAssignment in $tagAssignments) {
            $tag = $tagAssignment.Tag
            $categoryName = $tag.Category.Name.ToLower()
            
            if ($tagsByCategory.ContainsKey($categoryName)) {
                if ($tagsByCategory[$categoryName]) {
                    $tagsByCategory[$categoryName] += ";$($tag.Name)"
                } else {
                    $tagsByCategory[$categoryName] = $tag.Name
                }
            }
        }
        
        $vmObject = [PSCustomObject]@{
            'asset type' = 'VIRTUAL_MACHINE'
            'asset id' = $vm.Id
            'asset ip' = $ipAddresses
            'asset name' = $vm.Name
            'region' = $tagsByCategory['region']
            'zone' = $tagsByCategory['zone']
            'environment' = $tagsByCategory['environment']
            'application' = $tagsByCategory['application']
            'application tier' = $tagsByCategory['application tier']
            'infrastructure service' = $tagsByCategory['infrastructure service']
        }
        
        $results += $vmObject
    }
    
    Write-Host "Exporting to CSV: $OutputPath" -ForegroundColor Cyan
    $results | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
    
    Write-Host "Export completed successfully!" -ForegroundColor Green
    Write-Host "Total VMs exported: $($results.Count)" -ForegroundColor Green
    Write-Host "Output file: $OutputPath" -ForegroundColor Green
    
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    exit 1
} finally {
    if ($global:DefaultVIServer) {
        Write-Host "Disconnecting from vCenter..." -ForegroundColor Cyan
        Disconnect-VIServer -Server * -Confirm:$false
        Write-Host "Disconnected." -ForegroundColor Green
    }
}

# SIG # Begin signature block
# MIIFfAYJKoZIhvcNAQcCoIIFbTCCBWkCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUOxDq6JKFL+dEUDpHRaOG97PZ
# 5bCgggMSMIIDDjCCAfagAwIBAgIQSkuiNV8kXpREnLlnjK5VZjANBgkqhkiG9w0B
# AQsFADAfMR0wGwYDVQQDDBR2RGVmZW5kIENvZGUgU2lnbmluZzAeFw0yNjA3MTQy
# MTEwMjRaFw0yNzA3MTQyMTMwMjRaMB8xHTAbBgNVBAMMFHZEZWZlbmQgQ29kZSBT
# aWduaW5nMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEArETdbIfkIPRV
# +Ww9twDcYrdewlnVKz5Mc1EHOneUHu2rM8TQDB1b1E+Dx36Vi4HgvZbKZb+GvG+X
# 7eI1H9UzNvXrJcVeJNwwkNV9tkN1pPWxg0Q6wxc/UIvyB6hhFeVF1lj0oYmFryKA
# E6NL1B/FUorS4RdjkQ4ib9iu19ENq+au/XyOtrx2edm/9WF7NB+jY/SrybSmDMmq
# LWuKvb0kYjYGSarH/T6WBjvIY5VrjTA7DLi6GHwQfOhf5gzkNl6jThAJQvSBweCL
# GAkxDsQEuSr02NHv+funPtLPGPaJx/SioYCb+xTIIGjcbo4j9uzBt1kz7NHEGIJm
# /Yy4Dzsm9QIDAQABo0YwRDAOBgNVHQ8BAf8EBAMCB4AwEwYDVR0lBAwwCgYIKwYB
# BQUHAwMwHQYDVR0OBBYEFMe1/2ud2m+1NGTlDgrD4LuEwmNUMA0GCSqGSIb3DQEB
# CwUAA4IBAQBQuZB+8agRRWkBhlWLSy3QH7q48+Tl3IjPAIOkOOyeQEB6HALS1RIN
# lNJhODDkGFl9ay5OckMyrqx3Za+8AkrAGQtdifKYQkUOf2KnF2KuRnYRNYzR9P6e
# GfscoEU23pKX1Rvap2hGvtO0FZv6xtwi/h4OELaKhOBMkGM9/zzbbJwkKF81AEiJ
# BK/KqzMeR4SlNvc2oSu6yhP4/3/8dds2Xhkz1/goKaA54huN8tLYVPrhWo+IMZe5
# ejU4Pt3NlNu0/ewER31Gu0b12mFsl59wehiliIzToS3o8IpGgtNiNkdbR268HLwP
# 7nYc5VxTEw5QIpljebQPM4AtEAN6Dqx0MYIB1DCCAdACAQEwMzAfMR0wGwYDVQQD
# DBR2RGVmZW5kIENvZGUgU2lnbmluZwIQSkuiNV8kXpREnLlnjK5VZjAJBgUrDgMC
# GgUAoHgwGAYKKwYBBAGCNwIBDDEKMAigAoAAoQKAADAZBgkqhkiG9w0BCQMxDAYK
# KwYBBAGCNwIBBDAcBgorBgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG
# 9w0BCQQxFgQUf5Z8hZ8q4NB/og8pBsCZU1CeM2kwDQYJKoZIhvcNAQEBBQAEggEA
# UdHNG0hnvoiQfPE5YN/vdqoq4uTZdpCMu1PncTRQ98IjISCRkDTXTPIJDX4s1R6z
# B3sECK6CeTcf3zT4XsD5Q1MtnH2zNYRmUDpzqyS2IgyWI+elCLxGk4YS00vIN/wo
# XXHIkp2M3CHVQKKZB3GF5eSWtQEIyyRgrMfOo3CGOt5sp5dhb815SWKONgb1Ng+P
# 3p4a2JEWHysIS12yShur93HZls6KJf/0XgFmtaWIpv/hqGKxwyrjbOlkYVIKEbd6
# tt979dBjbwP6KsiUOjPkoZNCN5aBBSZQm/Fk1yvrMAOX4wvznkhg+uTPdharW9X7
# YoSJRnb7Wrweq+IziZi46A==
# SIG # End signature block
