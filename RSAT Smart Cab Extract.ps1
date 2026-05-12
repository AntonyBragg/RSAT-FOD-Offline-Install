<#
.SYNOPSIS
    Short Summary

.DESCRIPTION
    Longer more detailed description

    https://learn.microsoft.com/en-us/azure/virtual-desktop/windows-11-language-packs

.PARAMETER FoDIsoFolder
    The folder containing the FOD ISO file.

.PARAMETER DestinationFolder
    The destination folder where the extracted CAB files will be copied to.

.EXAMPLE
    .\RSAT-Smart-Cab-Extract.ps1 -FoDIsoFolder "C:\temp\iso" -DestinationFolder "C:\temp\rsat_cabs"
    This example extracts the RSAT CAB files from the specified source folder and copies them to the specified destination folder.

.NOTES
    Created By        : Name
    Creation Date     : DD/MM/YYYY
    Last Updated By   : Name
    Last Updated      : DD/MM/YYYY
    Script Version    : 1.0.0
    Template Version  : 3.0.0

    This script is provided without warranties, guarantees, referees, or Applebee's. Don't run code you haven't investigated. You will need to be an admin to do these things, almost certainly. This script will overwrite the contents of the defined folders. Comment out Step 9 if you don't want to check back and make sure you got all the apps.

    When complete it will spit out a list of available apps to $DestinationFolder\rsatapps.txt

.LINK
    GitHub Repository : https://github.com/Gen2Training/PowerShell-Template
    Documentation     : https://github.com/Gen2Training/PowerShell-Template/blob/main/README.md
    Change Log        : https://github.com/Gen2Training/PowerShell-Template/blob/main/CHANGELOG.MD
#>

#-----[ Requirements ]-----#

#Requires -RunAsAdministrator

#-----[ Script Parameters ]-----#

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true, HelpMessage = "The folder containing the FOD ISO.")]
    [ValidateNotNullOrEmpty()]
    [string] $FODIsoFolder,

    [Parameter(Mandatory = $false, HelpMessage = "The destination folder where the extracted CAB files will be copied to.")]
    [ValidateNotNullOrEmpty()]
    [string] $DestinationFolder = "$FODIsoFolder\Extracted",

    [Parameter(Mandatory = $false, HelpMessage = "Install features as well as extract.")]
    [switch]
    $Install,

    [Parameter(Mandatory = $false, HelpMessage = "Extract only common features.")]
    [switch]
    $CommonFeaturesOnly
)

#-----[ Execution ]-----#

Write-Host "Starting RSAT CAB file extraction from $FODIsoFolder to $DestinationFolder"

Write-Verbose "Checking if source folder exists: $FODIsoFolder"
if (-not (Test-Path -Path $FODIsoFolder -PathType Container)) {
    Write-Error "Source folder does not exist: $FODIsoFolder"
    exit 1
}

$FODisos = Get-ChildItem -Path $FODIsoFolder -Filter "*.iso" -File -ErrorAction Stop
switch ($FODisos.Count) {
    0 {
        throw "No ISO file found in the source folder: $FODIsoFolder. Please place the ISO file in the folder and try again."
    }
    1 {
        try { 
            $mountResult = Mount-DiskImage -ImagePath $FODisos.FullName -PassThru -ErrorAction Stop
            $driveLetter = ($mountResult | Get-Volume).DriveLetter
            
            if ([string]::IsNullOrWhiteSpace($driveLetter)) {
                Write-Error "Failed to retrieve drive letter from mounted ISO"
                exit 1
            }
            
            $source = "$($driveLetter):\LanguagesAndOptionalFeatures"
            Write-Verbose "Mounted ISO at drive letter: $driveLetter`:\LanguagesAndOptionalFeatures"
            
            if (-not (Test-Path -Path $source -PathType Container)) {
                Write-Error "Expected ISO folder not found at: $source"
                exit 1
            }
        } catch {
            Write-Error "Failed to mount ISO: $_"
            exit 1
        }
    }
    default {
        throw "Multiple ISO files found in the source folder: $FODIsoFolder. Please leave only one ISO."
    }
}

if (-not (Test-Path -Path $DestinationFolder -PathType Container)) {
    Write-Verbose "Creating destination folder: $DestinationFolder"
    try {
        New-Item -ItemType Directory -Path $DestinationFolder -Force | Out-Null
    } catch {
        Write-Error "Failed to create destination folder: $_"
        exit 1
    }
}

Write-Verbose "Retrieving list of RSAT capabilities from the system"
$rsatCapabilities = Get-WindowsCapability -Name RSAT* -Online | Select-Object -ExpandProperty Name |
    Where-Object { $_.State -eq "NotPresent" }

foreach ($capability in $rsatCapabilities) {
    Write-Verbose "Processing capability: $capability"
    $featureParts = $capability -split "\."

    Write-Verbose "Looking for CAB files matching: *$($featureParts[1])* in $source"
    $cabFiles = Get-ChildItem -Path $source -Filter "*$($featureParts[1])*" | 
                Where-Object { $_.Name -like "*amd64~~.cab" -or $_.Name -like "*amd64~en-us~.cab" }

    Write-Verbose "Copying CAB files for capability: $capability to $DestinationFolder"
    foreach ($cab in $cabFiles) {
        $destinationPath = Join-Path -Path $DestinationFolder -ChildPath $cab.Name
        Copy-Item -Path $cab.FullName -Destination $destinationPath -Force
        Write-Verbose "Copied: $($cab.Name)"
    }
}

$additionalFiles = @(
    "FoDMetadata_Client.cab",
    "Downlevel-NLS-Sorting-Versions-Server-FoD-Package~31bf3856ad364e35~amd64~~.cab"
)

foreach ($file in $additionalFiles) {
    Write-Verbose "Looking for additional file: $file in $source"
    $filePath = Join-Path -Path $source -ChildPath $file
    if (Test-Path -Path $filePath) {
        Write-Verbose "Copying additional file: $file to $DestinationFolder"
        Copy-Item -Path $filePath -Destination $DestinationFolder
        Write-Verbose "Copied: $file"
    } else {
        Write-Error "File $file not found in $source"
    }
}

$metadataSourcePath = Join-Path -Path $source -ChildPath "metadata"  # Source \metadata folder
$metadataDestinationPath = Join-Path -Path $DestinationFolder -ChildPath "metadata"  # Destination \metadata folder

try {
    Write-Verbose "Creating metadata destination folder: $metadataDestinationPath"
    New-Item -ItemType Directory -Path $metadataDestinationPath -Force | Out-Null
} catch {
    Write-Error "Failed to create metadata destination folder: $_"
    exit 1
}

Get-ChildItem -Path $metadataSourcePath -Recurse | 
    Where-Object { $_.Name -like "*en-US*" -or $_.Name -like "DesktopTargetCompDB_*" } |
    Copy-Item -Destination $metadataDestinationPath

Get-WindowsCapability -Name RSAT* -Online -Source "$DestinationFolder" |
    Select-Object -ExpandProperty Name |
    Out-File -FilePath "$DestinationFolder\rsatapps.txt" -Encoding ASCII

try {
    Write-Host "Dismounting ISO from drive letter: $driveLetter"
    Dismount-DiskImage -ImagePath $FODisos.FullName -ErrorAction Stop | out-null
    Write-Verbose "Successfully dismounted ISO."
} catch {
    Write-Error "Failed to dismount ISO: $_"
} 

Write-Host "RSAT CAB file extraction completed!" -ForegroundColor Green

if ($Install) {
    Write-Host "Starting installation of RSAT features from extracted CAB files..." -ForegroundColor Green
    $RSATFod = Get-WindowsCapability -Name RSAT.* -Online -Source $DestinationFolder

    foreach ($Item in $RSATFod) {
        Write-Host "Installing: $($Item.Name)" -ForegroundColor Cyan

        & dism.exe /Online /Add-Capability "/CapabilityName:$($Item.Name)" "/Source:$DestinationFolder" /LimitAccess

        if ($LASTEXITCODE -ne 0) {
            Write-Warning "DISM failed for '$($Item.Name)' with exit code $LASTEXITCODE"
        } else {
            Write-Host "Successfully installed '$($Item.Name)'" -ForegroundColor Green
        }
    }

    Write-Host "RSAT feature installation completed!" -ForegroundColor Green
}