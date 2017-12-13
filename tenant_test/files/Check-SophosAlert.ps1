<#     
    .SYNOPSIS
       Check if Sophos detected a virus
    .DESCRIPTION
       This script will check (during Check_MK run) if Sophos detected a virus. 
    .PARAMETER <Parameter name> (repeat this block if you have multiple parameters)
       No external Parameters are rquired
    .EXAMPLE
        <How to run this script example>
    .NOTES
        ===========================================================================
        Created on:       10/06/2017
        Last edited on:   10/06/2017
        Created by:       Bart P.C. Vrakking
       Last Edited by:   Bart P.C. Vrakking  
        Organization:     QNH NextGen Hosting    
        Version:          0.1 - Initial version
                          0.2 - Added Check Log Name
                          0.3 - Added Check_MK function
        ===========================================================================

#>
## Params
$LogSource = 'QNH NGH'
$Logname   = 'Application'
$AVLogDir  = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\WOW6432Node\Sophos\SAVService\Application').logdir
$AVLogfile = 'SAV.txt'

## Functions
function Write-Check_Mk { 
    ## Check MK alert codes ok=0; warning=1; critical=2 unknown=3
  [cmdletbinding()]  
  param 
    (
    [Parameter(Mandatory=$true)]$p1,    [Parameter(Mandatory=$true)]$p2,    [Parameter(Mandatory=$true)]$p3,    [Parameter(Mandatory=$true)]$p4
    )
  write-output "$p1 $p2 $p3 $p4" 
}

## Check if Eventlog Sophos Update entry is present and create if not
$EventSophos  = !!(Get-Eventlog -InstanceId 1 -Source $LogSource -LogName $Logname -Newest 1 -ErrorAction SilentlyContinue)
if ($EventSophos -eq $false)
{
  New-EventLog -LogName $Logname -Source $LogSource
  Write-EventLog -LogName $Logname -Source $LogSource -EntryType 'Information' -EventID 1 -Message 'QNH NextGen Hosting EventLog Source Created'
}

## Check if SAV log exists
if (test-path -Path ('{0}\{1}' -f $AVLogDir, $AVLogfile))
{
  if (Get-ChildItem -Path ('{0}\{1}' -f $AVLogDir, $AVLogfile) | Where-Object{$_.LastWriteTime -gt $((Get-Date).AddMinutes(-5))})
  {
    if (Get-Content -Path ('{0}\{1}' -f $AVLogDir, $AVLogfile) | Where-Object { $_ -match 'Virus/spyware' })
    {
      ## Get Alert
      $AVAlert = (Get-Content -Path ('{0}\{1}' -f $AVLogDir, $AVLogfile) | Where-Object { $_ -match 'Virus/spyware' } | Select-Object -Last 1).Substring(16)
      $AVAction = (Get-Content -Path ('{0}\{1}' -f $AVLogDir, $AVLogfile) | Where-Object { $_ -notmatch 'Virus/spyware' } | Select-Object -Last 1).Substring(16)
      ## Create Eventlog Message
      $AVMessage = @"
ComputerName : $env:COmputerName
Alert               : $AVAlert
Action                    : $AVAction
"@
      ## Write Eventlog
      Write-EventLog -LogName $Logname -Source $LogSource -EntryType Warning -EventId 1 -Message $AVMessage
      
      ## Write Check_MK Output
      $MK1_AlertLevel  = 2
      $MK2_UniqueName  = 'Sophos_ALERT'
      $MK3_PerfData    = 'Sophos_VIRUS_FOUND'
      $MK4_Description = "$AVAlert"
  
      Write-Check_Mk $MK1_AlertLevel $MK2_UniqueName $MK3_PerfData $MK4_Description
    }
  }
}
