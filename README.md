# RSAT-FOD-Offline-Install

Offline RSAT installation for Windows 11 using the Features on Demand ISO.

This repository contains scripts and guidance for extracting the offline RSAT payload from the Windows 11 Optional Features ISO and installing the RSAT capabilities without relying on Windows Update or WSUS.

---

## Overview

This approach is useful when your environment cannot reach Windows Update or when firewall/authentication changes break online RSAT installs.

Key benefits:
- Install RSAT offline using local source files
- Avoid dependency on Windows Update / WSUS during install
- Filter the ISO payload to only RSAT packages
- Support deployment via SCCM/MECM/Intune or manual execution

---

## Repository Files

- `RSAT Smart Cab Extract.ps1` - filters and extracts the RSAT-related CAB files from the Optional Features ISO.
- `Windows 11 RSAT FOD Offline Install.ps1` - installs RSAT features offline using the extracted cab source.

---

## What you need

- Windows 11 Features on Demand ISO ("Language and Optional Features")
- `amd64` and `en-US` media for your target machines
- PowerShell elevated as Administrator
- Local or network location containing the extracted source files

---

## Step 1: Download and extract the ISO

Download the Windows 11 Optional Features ISO from [my.visualstudio.com](https://my.visualstudio.com) or from your Visual Studio/MSDN downloads portal. Search for the "Language and Optional Features for Windows 11" ISO.

Once downloaded, extract the `LanguageAndOptionalFeatures` folder content. You can either mount the ISO or use 7-Zip.

You should end up with two folders:
- `LanguageAndOptionalFeatures`
- `Windows Preinstallation Environment`

Only the `LanguageAndOptionalFeatures` folder is needed for RSAT.

---

## Step 2: Filter the CAB files for RSAT

The folder contains thousands of CAB files plus metadata files. A simple filter of only `amd64` and `en-US` language CABs is not enough because the install also needs base and utility CABs such as:

- `FoDMetadata_Client.cab`
- `Downlevel-NLS-Sorting-Versions-Server-FoD-Package~31bf3856ad364e35~amd64~~.cab`

Use `RSAT Smart Cab Extract.ps1` to extract only the RSAT-relevant CABs and the required metadata.

Create a layout like:

```
C:\temp\extract\
  ├── *.cab
  └── metadata\
      └── *.cab
```

---

## Step 3: Verify the source and available RSAT packages

Confirm that your source path contains the expected RSAT packages:

```powershell
Get-WindowsCapability -Name RSAT* -Online -Source "C:\temp\extract" | Select-Object -Property Name
```

If the source is valid, you should see the RSAT package names listed.

---

## RSAT package list

The packages this repo targets include:

- `Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0`
- `Rsat.AzureStack.HCI.Management.Tools~~~~0.0.1.0`
- `Rsat.BitLocker.Recovery.Tools~~~~0.0.1.0`
- `Rsat.CertificateServices.Tools~~~~0.0.1.0`
- `Rsat.DHCP.Tools~~~~0.0.1.0`
- `Rsat.Dns.Tools~~~~0.0.1.0`
- `Rsat.FailoverCluster.Management.Tools~~~~0.0.1.0`
- `Rsat.FileServices.Tools~~~~0.0.1.0`
- `Rsat.GroupPolicy.Management.Tools~~~~0.0.1.0`
- `Rsat.IPAM.Client.Tools~~~~0.0.1.0`
- `Rsat.LLDP.Tools~~~~0.0.1.0`
- `Rsat.NetworkController.Tools~~~~0.0.1.0`
- `Rsat.NetworkLoadBalancing.Tools~~~~0.0.1.0`
- `Rsat.RemoteAccess.Management.Tools~~~~0.0.1.0`
- `Rsat.RemoteDesktop.Services.Tools~~~~0.0.1.0`
- `Rsat.ServerManager.Tools~~~~0.0.1.0`
- `Rsat.StorageMigrationService.Management.Tools~~~~0.0.1.0`
- `Rsat.StorageReplica.Tools~~~~0.0.1.0`
- `Rsat.SystemInsights.Management.Tools~~~~0.0.1.0`
- `Rsat.VolumeActivation.Tools~~~~0.0.1.0`
- `Rsat.WSUS.Tools~~~~0.0.1.0`

> Keep `Downlevel` and `FoDMetadata` CABs as part of the source set.

---

## Step 4: Install RSAT offline

Run the installer script from an elevated PowerShell session:

```powershell
.\Windows 11 RSAT FOD Offline Install.ps1 -Source "C:\temp\extract"
```

In the installer script, make sure `Add-WindowsCapability` is invoked with `-LimitAccess` so the install is limited to the local source.

---

## Step 5: Optional deployment via SCCM / Intune

This repository works well with deployment frameworks such as MECM. Use detection logic based on installed RSAT tools, for example:

- `dsac.exe`
- `dnsmgmt.msc`
- `bitlockerdeviceencryption.exe`
- `dhcpmgmt.msc`

The install script includes comments that make it easy to integrate with SCCM or Intune.

---

## Troubleshooting

### Access Denied errors

If the install fails with `Access Denied`, verify that the command includes `-LimitAccess` when calling `Add-WindowsCapability`.

### Cannot Find Source Files error

If PowerShell reports missing source files, one or more CABs or metadata files are missing from your source path. If needed, include all metadata files from the ISO folder.

---

## Notes

- This guidance was created using Windows 11 22H3 and SCCM/MECM 2309.
- Adjust language and architecture settings as needed for non-`en-US` or non-`amd64` environments.
- If you only need a subset of RSAT capabilities, filter the package list before installation:

```powershell
$RSAT_FoD = Get-WindowsCapability -Online | Where-Object Name -like 'RSAT.ActiveDirectory*'
```
