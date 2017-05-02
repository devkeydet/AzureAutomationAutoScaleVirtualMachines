using Microsoft.WindowsAzure.Storage.Table;

namespace PerfCounterHelperLibrary
{
    public class PerformanceCountersEntity : TableEntity
    {
        public long EventTickCount { get; set; }
        public string DeploymentId { get; set; }
        public string Role { get; set; }
        public string RoleInstance { get; set; }
        public string CounterName { get; set; }
        public double CounterValue { get; set; }
    }
}