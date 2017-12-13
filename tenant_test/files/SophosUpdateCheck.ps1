<#     
    .SYNOPSIS
       Check if Sophos is updated
    .DESCRIPTION
       This script will run Puppet run to check if Sophos definitions are up to date. 
    .PARAMETER <Parameter name> (repeat this block if you have multiple parameters)
       <Define Start Parameters>
    .EXAMPLE
        <How to run this script example>
    .NOTES
        ===========================================================================
        Created on:        31/08/2017
        Last edited on:    29/09/2017
        Created by:        Bart P.C. Vrakking
        Last Edited by:    Bart P.C. Vrakking  
        Organization:      QNH NextGen Hosting    
        Version:           0.1 - Template
                           0.2 - Initial Script 
                           0.3 - Ise OnSteroids Changes
                           0.5 - Added Params
                           0.6 - Performance tweak 13 second to 9 milliseconds
                           0.7 - Added Check_MK output
                           0.8 - Changed write to Eventlog
                           0.9 - Added Functions
        ===========================================================================

#>

## Params
$LogSource   = 'Sophos Update'
$Logname     = 'Application'
$Application = 'Sophos'

## Functions
function Get-Installed {
  [cmdletbinding()]
  param
  (
    [Parameter(Mandatory=$true)][string]$Program
  )
  
  $x86 = ((Get-ChildItem -Path 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall') |
        Where-Object { $_.GetValue( 'DisplayName' ) -like ('*{0}*' -f $Program) } ).Length -gt 0

  $x64 = ((Get-ChildItem -Path 'HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall') |
        Where-Object { $_.GetValue( 'DisplayName' ) -like ('*{0}*' -f $Program) } ).Length -gt 0

  return $x86 -or $x64
}
function Write-Check_Mk { 
    # ok=0; warning=1; critical=2 unknown=3
  [cmdletbinding()]  
  param 
    (
    [Parameter(Mandatory=$true)]$p1,    [Parameter(Mandatory=$true)]$p2,    [Parameter(Mandatory=$true)]$p3,    [Parameter(Mandatory=$true)]$p4
    )
  write-output "$p1 $p2 $p3 $p4" 
}

## Check if Eventlog Sophos Update entry is present and create if not
$EventSophos = !!(Get-Eventlog -InstanceId 1 -Source $LogSource -LogName $Logname -Newest 1 -ErrorAction SilentlyContinue)
if ($EventSophos -eq $false)
{
  New-EventLog -LogName $Logname -Source $LogSource
  Write-EventLog -LogName $Logname -Source $LogSource -EntryType 'Information' -EventID 1 -Message 'QNH NextGen Hosting: Sophos EventLog Source Created'
}

## Check if Sophos is installed
if (Get-Installed -program $Application)
{
  ## Get Update time difference 
  $Reg = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Wow6432Node\Sophos\AutoUpdate\UpdateStatus'
  $LastUpdateTimeTimer = $Reg.LastUpdateTime
  [datetime]$StartDate = '01/01/1970 00:00:00'
  $LastUpdateTime = $StartDate.AddSeconds($LastUpdateTimeTimer).ToLocalTime()
  [int]$UpdateDiff = ($LastUpdateTime - (get-date)).Days
  
  ## Create Event / Check_MK Codes
  switch ($UpdateDiff) 
  { 
    0 {$EventEntryType = 'Information'; $MK1_AlertLevel = 0} 
    1 {$EventEntryType = 'Information'; $MK1_AlertLevel = 0} 
    2 {$EventEntryType = 'Warning'    ; $MK1_AlertLevel = 1} 
    3 {$EventEntryType = 'Warning'    ; $MK1_AlertLevel = 1} 
    4 {$EventEntryType = 'Warning'    ; $MK1_AlertLevel = 1}  
    default {$EventEntryType = 'Error'; $MK1_AlertLevel = 2}
  }
  
  ## Write EventLog
  If ($MK1_AlertLevel -ge 1)
  {
    Write-EventLog -LogName $Logname -Source $LogSource -EntryType $EventEntryType -EventID 1 -Message "Last Sophos Update: $lastUpdateTime"
  }
  
  ## Write Check_MK Output
  $MK2_UniqueName  = 'Sophos_LastUpdateTime'
  $MK3_PerfData    = "LastUpdateTime=$lastUpdateTime"
  $MK4_Description = "$EventEntryType - LastUpdateTime=$lastUpdateTime"
  
  Write-Check_Mk $MK1_AlertLevel $MK2_UniqueName $MK3_PerfData $MK4_Description  
}
else
{
  ## Write Check_MK Output
  $MK1_AlertLevel  = 0
  $MK2_UniqueName  = 'Sophos_Installation'
  $MK3_PerfData    = 'Sophos_Installation_not_found'
  $MK4_Description = 'No Installation of Sophos Found'
  
  Write-Check_Mk $MK1_AlertLevel $MK2_UniqueName $MK3_PerfData $MK4_Description  
} 
