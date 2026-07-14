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
        
        if (-not $tagAssignments -or $tagAssignments.Count -eq 0) {
            Write-Host "  Skipping: No tags assigned" -ForegroundColor Gray
            continue
        }
        
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
        
        $hasRelevantTags = $false
        foreach ($value in $tagsByCategory.Values) {
            if ($value) {
                $hasRelevantTags = $true
                break
            }
        }
        
        if (-not $hasRelevantTags) {
            Write-Host "  Skipping: No tags match required categories" -ForegroundColor Gray
            continue
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
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUUK7E04q7GbIlXSHGQcNZZbsk
# dbOgggMSMIIDDjCCAfagAwIBAgIQNANyaT2m96pPJErLs1AwKjANBgkqhkiG9w0B
# AQsFADAfMR0wGwYDVQQDDBR2RGVmZW5kIENvZGUgU2lnbmluZzAeFw0yNjA3MTQy
# MDM4MzlaFw0yNzA3MTQyMDU4MzlaMB8xHTAbBgNVBAMMFHZEZWZlbmQgQ29kZSBT
# aWduaW5nMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAw0RJd4ilDI7I
# iz7avz5HYDm14hbAvRCOTZs95izSWm21IAtPtljh6zta39SAih89Du7C+RVj9vjD
# b2HMblmrIZUlS5WjuPV0GoL1HOBemb8SZvUpDoMUs9Sydz7y3iDX+TNhagSu15x+
# AlcluuiVVAusIT1QJTfJxS1K+D/qKPv8PrxFonWlDHzkoR2mvjbdXeXrCVVMk2Yy
# 5nXGDNmKgy9RuV4fMXkiLwy42QTOkZfT/aO1vM3Grs9SF8surKFNts3B1uaXAZ2s
# /RxftJpRxfqR9edbVOqjA+IZ3+xHgE8HohYx+1TUCgw5DyTC7q+OvCDa62yQ6K82
# z66wsM1xqQIDAQABo0YwRDAOBgNVHQ8BAf8EBAMCB4AwEwYDVR0lBAwwCgYIKwYB
# BQUHAwMwHQYDVR0OBBYEFHULkVrxwenUoAppjo/H2kbbhHZ1MA0GCSqGSIb3DQEB
# CwUAA4IBAQBPNJEyrMPujUXSf8Dn8//f9d0Ux7BB0ibDfZOu42MFXyuVqlgcM8Ns
# F1JNt+renyiV1yWxmyJ8uqmnAnzwqajFSUZdSEGRxnistjAwW4iYiSLJ8AymcWFi
# cx3oXLRwBHhu2E/Tl7SI7n1vupKq+JKGzk+vYZVgt6wg1o9ekplBbEpDI94F7UZL
# oXCWAFshbiLIEWu+Cf9I+bUch76rsJcT85p6yTgPP2Wt3mZ8LBybA2KJKbvbPwH1
# 2dveEsj1jFXhRPGUI87oVq+mArpV77a6upVTsSU9cJ+TDmdxh6bqwkCZpEYq0D3D
# dzY3UDSMXYo3noIMjhK+TqsCFyPvHHYYMYIB1DCCAdACAQEwMzAfMR0wGwYDVQQD
# DBR2RGVmZW5kIENvZGUgU2lnbmluZwIQNANyaT2m96pPJErLs1AwKjAJBgUrDgMC
# GgUAoHgwGAYKKwYBBAGCNwIBDDEKMAigAoAAoQKAADAZBgkqhkiG9w0BCQMxDAYK
# KwYBBAGCNwIBBDAcBgorBgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG
# 9w0BCQQxFgQUeRlTqgIuzJgcLJT5J1b9rJ2FFacwDQYJKoZIhvcNAQEBBQAEggEA
# i++caHxwAJ+huqpw3Bb9hzW5H1XjsGSgxQ9HV/qx853dTS2e/NqVkZXTR+FI+Iht
# AU+z+9FUAHhTjGFMnZOVzP0xHc1FDHL+PG8oHD5Kloj+R1B2MTTlfV/cQ+5w4bs+
# gb/tVfUMC36NNAazTjD+5tdGXEbajv7jX25LZ1nVKH4stgiXHgNJnVroLyWZ88E1
# CKY33MePIwIxN4V3IDDNv5ZBN+hMxjxd3uMVDrRGrkyFzOKz3vqgzBPIBe9Aj2HS
# QXhc3QgW5mBHuRt2MWtvuw7YdniO4kO8J4RrR3QDrhqwliLvVQT7viMNKRbAeJbQ
# mjjJ5CsPb4qTaUvkUkLGnA==
# SIG # End signature block
