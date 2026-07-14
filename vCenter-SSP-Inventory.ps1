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
    
    if (-not $vCenterServer -or -not $vCenterUsername -or -not $vCenterPassword) {
        throw "Missing required environment variables. Please set VCENTER_HOST, VCENTER_USERNAME, and VCENTER_PASSWORD."
    }
    
    Write-Host "Environment variables found." -ForegroundColor Green
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
