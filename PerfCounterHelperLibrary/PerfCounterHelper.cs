using System;
using System.Collections.Generic;
using System.Linq;
using Microsoft.WindowsAzure.Storage;
using Microsoft.WindowsAzure.Storage.Table;

namespace PerfCounterHelperLibrary
{
    public static class PerfCounterHelper
    {
        public static List<PerformanceCountersEntity> GetPerformanceCountersFromDiagnosticsStorage(
            string storageConnectionString,
            int lastXMinutes,
            string vmName,
            string metric
        )
        {
            var storageAccount = CloudStorageAccount.Parse(storageConnectionString);

            var tableClient = storageAccount.CreateCloudTableClient();

            var table = tableClient.GetTableReference("WADPerformanceCountersTable");

            var query = new TableQuery<PerformanceCountersEntity>()
                .Where(
                    TableQuery.CombineFilters(
                        TableQuery.GenerateFilterCondition("PartitionKey", QueryComparisons.GreaterThanOrEqual,
                            $"0{DateTime.Now.ToUniversalTime().AddMinutes(lastXMinutes * -1).Ticks}"),
                        TableOperators.And,
                        TableQuery.CombineFilters(
                            TableQuery.GenerateFilterCondition("CounterName", QueryComparisons.Equal, metric),
                            TableOperators.And,
                            TableQuery.GenerateFilterCondition("RoleInstance", QueryComparisons.Equal, $"_{vmName}")
                        )
                    )
                );
            
            var result = table.ExecuteQuery(query);

            return result.ToList();
        }
    }
}