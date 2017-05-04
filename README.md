## Overview
This is adaptation of the 
[Custom Auto Scaling for Azure ARM Virtual�Machines](
    https://shiningdragonsoftware.net/2016/11/10/custom-auto-scaling-for-azure-arm-virtual-machines/
) sample.
The goal of the adaptation is to get the original sample working in 
[Azure Government](
    https://azure.microsoft.com/en-us/overview/clouds/government/
).
The
[Custom Auto Scaling for Azure ARM Virtual�Machines](
    https://shiningdragonsoftware.net/2016/11/10/custom-auto-scaling-for-azure-arm-virtual-machines/
) 
blog post does a good job explaining the scenarios when one would want to use this approach.
Unfortunately, the
[Custom Auto Scaling for Azure ARM Virtual�Machines](
    https://shiningdragonsoftware.net/2016/11/10/custom-auto-scaling-for-azure-arm-virtual-machines/
) 
sample uses the
[Get-AzureRmMetric](
    https://msdn.microsoft.com/en-us/library/mt718050.aspx
) command, which doesn't work with
[Azure Government](
    https://azure.microsoft.com/en-us/overview/clouds/government/
) as of 5/2/2017.
Once the
[Get-AzureRmMetric](
    https://msdn.microsoft.com/en-us/library/mt718050.aspx
) command works with
[Azure Government](
    https://azure.microsoft.com/en-us/overview/clouds/government/
), you should consider using the orginal sample.

## Geting Started
This code was created using 
[Visual Studio 2017](https://www.visualstudio.com/downloads/).  Review the following blog post for instructions to get it up and running: [https://blogs.msdn.microsoft.com/devkeydet/2017/05/03/custom-autoscale-for-arm-virtual-machines-in-azure-government/](https://blogs.msdn.microsoft.com/devkeydet/2017/05/03/custom-autoscale-for-arm-virtual-machines-in-azure-government/).