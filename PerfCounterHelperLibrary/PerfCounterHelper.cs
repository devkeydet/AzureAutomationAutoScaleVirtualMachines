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
            // Get a reference to the storage account using the connection string.  You can also use the development
            // storage account (Storage Emulator) for local debugging.
            var storageAccount = CloudStorageAccount.Parse(storageConnectionString);

            // Create the table client.
            var tableClient = storageAccount.CreateCloudTableClient();


            // Create the CloudTable object that represents the "WADPerformanceCountersTable" table.
            var table = tableClient.GetTableReference("WADPerformanceCountersTable");

            // Create the table query, filter on a specific CounterName, DeploymentId and RoleInstance.
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

            // Execute the table query.
            var result = table.ExecuteQuery(query);

            return result.ToList();
        }
    }
}
