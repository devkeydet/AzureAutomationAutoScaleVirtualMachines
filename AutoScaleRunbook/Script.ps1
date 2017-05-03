<#
.SYNOPSIS
Auto scales a group of virtual machines.

.DESCRIPTION
Iterates through all servers and determines if they are below, in or above our prefered CPU utilistaion range
Powers on on off servers accordingly. A minumum of 2 servers is always left running.
Adapted from https://shiningdragonsoftware.net/2016/11/10/custom-auto-scaling-for-azure-arm-virtual-machines/
Tweaked to work with Azure Government.
For more details, see:
[INSERT BLOG POST]

.PARAMETER VirtualMachineNameString
An comma separated list of virtual machine names

.PARAMETER ResourceGroupName
The resource group containing our application

.PARAMETER Subscription
The subscription

.PARAMETER TimeRange
Time in minutes we use to calculate the CPU range

.PARAMETER MinCPUValue
The lower range of our prefered CPU usage

.PARAMETER MaxCPUValue
The upper range of our prefered CPU usage

.NOTES
AUTHOR: devkdeydet
LASTEDIT: May 2, 2017
#>

param(
	[Parameter(Mandatory=$true)][string]$Subscription,
	[Parameter(Mandatory=$true)][string]$ResourceGroupName,
	[Parameter(Mandatory=$true)][string]$DiagnosticsStorageConnectionString,
	[Parameter(Mandatory=$true)][string]$VirtualMachineNameString,
	[Parameter(Mandatory=$true)][int]$TimeRange,
	[Parameter(Mandatory=$true)][int]$MinCPUValue,
	[Parameter(Mandatory=$true)][int]$MaxCPUValue
)

$connectionName = "AzureRunAsConnection"
try
{
    # Get the connection "AzureRunAsConnection "
    $servicePrincipalConnection=Get-AutomationConnection -Name $connectionName

    "Logging in to Azure..."
    Add-AzureRmAccount `
        -ServicePrincipal `
        -TenantId $servicePrincipalConnection.TenantId `
        -ApplicationId $servicePrincipalConnection.ApplicationId `
        -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint `
        -EnvironmentName AzureUSGovernment
 }
catch {
    if (!$servicePrincipalConnection)
    {
        $ErrorMessage = "Connection $connectionName not found."
        throw $ErrorMessage
    } else{
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
}

# Reference .net dll with workaround since Get-AzureRmMetric
# is not supported in Azure Government as of 5/2/2017.
# This needs to be uploaded separately
Add-Type -Path "C:\Modules\User\PerfCounterHelperLibrary\PerfCounterHelperLibrary.dll"

Select-AzureRmSubscription -SubscriptionName $Subscription

$metricName = "\Processor(_Total)\% Processor Time"
$allServers = @()
$virtualMachineNames = $VirtualMachineNameString.Split(",")

foreach ($vmName in $virtualMachineNames)
{
    # Is vm started or stopped
	$vmstatus = Get-AzureRmVM -Name $vmName -ResourceGroupName "autoscalevm-rg" -Status
	$status = (get-culture).TextInfo.ToTitleCase(($vmstatus.statuses)[1].code.split("/")[1])
	$vmStarted = ($status -eq 'Running')

    # Get processor averages
	$averageProcessorPercentage = 0
	$inRange = 0

	# Uses a .net dll to make calls to get the metrics since Get-AzureRmMetric
	# is not supported in Azure Government as of 5/2/2017.
    $perfCounters = [PerfCounterHelperLibrary.PerfCounterHelper]::GetPerformanceCountersFromDiagnosticsStorage($DiagnosticsStorageConnectionString, 5, $vmName, $metricName)

    if($perfCounters -ne $null -and $perfCounters.Count -ge 0)
	{
        foreach ($perfCounter in $perfCounters)
        {
            $averageProcessorPercentage += $perfCounter.CounterValue
        }

        $averageProcessorPercentage = $averageProcessorPercentage / $perfCounters.Count

		# Is vm in performance range
		if($averageProcessorPercentage -lt $MinCPUValue)
		{
			$inRange = -1
		}
		elseif($averageProcessorPercentage -gt $MaxCPUValue)
		{
			$inRange = 1
		}
    }
    else
	{
		Write-Output "No metrics found for $vmName"
	}

    $allServers += @{"Name" = $vmName; "Started" = $vmStarted; "AverageProcessor"= $averageProcessorPercentage; "InRange"= $inRange}
}

$allServers | % { $_ | Format-Table -AutoSize}

Write-Output "All Servers"
$allServers | % {$_.Name}
$numberServers = $allServers.Count
Write-Output "Total number of servers: $numberServers"

Write-Output "Started Servers"
$startedServers = @($allServers | ? { $_.Started -eq $true })
$startedServers | % {$_.Name}
$numberServersStarted = $startedServers.Count
Write-Output "Total number of started servers: $numberServersStarted"

Write-Output "Stopped Servers"
$stoppedServers = @($allServers | ? { $_.Started -eq $false })
$stoppedServers | % {$_.Name}
$numberServersStopped = $stoppedServers.Count
Write-Output "Total number of stopped servers: $numberServersStopped"

Write-Output "In Range Servers"
$inRangeServers = @($startedServers | ? { $_.InRange -eq 0 })
$inRangeServers | % {$_.Name}
$numberServersInRange = $inRangeServers.Count
Write-Output "Total number of in range servers: $numberServersInRange"

Write-Output "Above Range Servers"
$aboveRangeServers = @($startedServers | ? { $_.InRange -eq 1 })
$aboveRangeServers | % {$_.Name}
$numberServersAboveRange = $aboveRangeServers.Count
Write-Output "Total number of above range servers: $numberServersAboveRange"

Write-Output "Below Range Servers"
$belowRangeServers = @($startedServers | ? { $_.InRange -eq -1 })
$belowRangeServers | % {$_.Name}
$numberServersBelowRange = $belowRangeServers.Count
Write-Output "Total number of below range servers: $numberServersBelowRange"

if($numberServers -le 2 )
{
	Write-Output "We only have 2  servers present so we can not scale in any direction"
	exit
}

# Autoscale logic - this should be customised for specific workflows, start and stop multiple vms at a time and  possibly improved to catch edge cases.
if($numberServersStarted -eq $numberServersInRange)
{
	Write-Output "All started servers are in range - do nothing"
	exit
}

if($numberServersAboveRange -ge $numberServersBelowRange + 1)
{
	Write-Output "We need to start one server"
	if($numberServersStopped -eq 0)
	{
		Write-Output "No servers available to start"
	}
	else
	{
		# Get first stopped server
		$stoppedServer = $stoppedServers[0]
		Write-Output "Starting server $($stoppedServer.Name)"
		Start-AzureRmVM -ResourceGroupName $ResourceGroupName -Name $($stoppedServer.Name)
	}
}
elseif($numberServersAboveRange -lt $numberServersBelowRange)
{
	if($numberServersStarted -le 2)
	{
		Write-Output "Only two servers running, cannot scale down"
	}
	else
	{
		# Get first started server
		Write-Output "We need to stop one server"
		$startedServer = $startedServers[0]
		Write-Output "Stopping server $($startedServer.Name)"
		Stop-AzureRmVM -ResourceGroupName $ResourceGroupName -Name $($startedServer.Name) -Force
	}
}