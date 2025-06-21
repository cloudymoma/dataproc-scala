#!/bin/bash

# --- Configuration Variables ---
# Your GCP Project ID
export PROJECT_ID=$(gcloud config get-value project)

# The GCP region to run the job in. Choose one near you or your data.
# Since you are in Beijing, asia-east2 (Hong Kong) or asia-northeast1 (Tokyo) are good choices.
export REGION="us-central1" # Example: Changhua County, Taiwan

# A unique name for this specific batch job run
export BATCH_ID="gcs-io-$(date +%Y%m%d-%H%M%S)"

# LOCAL_JAR_PATH=/usr/local/google/home/binwu/workspace/customers/yeahmobi/gcptest/target/scala-2.13/gcptest_2.13-0.1.0.jar
# The GCS path to your JAR, defined in the previous step
GCS_JAR_PATH="gs://dingoproc/jars/gcptest_2.12-0.1.0.jar"

# The GCS bucket for staging dependencies and logs
BUCKET_NAME="dingoproc"

export PHS_CLUSTER_NAME="dingohist"
export PHS_RESOURCE_NAME="projects/$PROJECT_ID/regions/$REGION/clusters/$PHS_CLUSTER_NAME"

export RUNTIME=1.2

#sbt clean package
#gcloud storage cp $LOCAL_JAR_PATH $GCS_JAR_PATH

__run_serverless() {
          # spark.executor.instances=2, \ # this is for dynamicAllocation=false
    # --- The gcloud Command ---
    gcloud dataproc batches submit spark \
        --project=$PROJECT_ID \
        --region=$REGION \
        --batch=$BATCH_ID \
        --class=GcpTest \
        --jars=$GCS_JAR_PATH \
        --deps-bucket=gs://$BUCKET_NAME/staging \
        --subnet=default \
        --version $RUNTIME \
        --history-server-cluster=$PHS_RESOURCE_NAME \
        --autotuning-scenarios=auto \
        --properties \
          "spark.executor.cores=4, \
          spark.executor.memory=25g, \
          spark.executor.memoryOverhead=4g, \
          spark.driver.cores=4, \
          spark.driver.memory=25g, \
          spark.driver.memoryOverhead=4g, \
          spark.dynamicAllocation.enabled=true, \
          spark.dynamicAllocation.initialExecutors=2, \
          spark.dynamicAllocation.minExecutors=2, \
          spark.dynamicAllocation.maxExecutors=100, \
          spark.dynamicAllocation.executorAllocationRatio=1.0, \
          spark.decommission.maxRatio=0.3, \
          spark.reducer.fetchMigratedShuffle.enabled=true, \
          spark.dataproc.scaling.version=2, \
          spark.dataproc.driver.compute.tier=premium, \
          spark.dataproc.executor.compute.tier=premium, \
          spark.dataproc.driver.disk.tier=premium, \
          spark.dataproc.driver.disk.size=375g, \
          spark.dataproc.executor.disk.tier=premium, \
          spark.dataproc.executor.disk.size=375g, \
          spark.sql.adaptive.enabled=true, \
          spark.sql.adaptive.coalescePartitions.enabled=true, \
          spark.sql.adaptive.skewJoin.enabled=true, \
          spark.dataproc.enhanced.optimizer.enabled=true, \
          spark.dataproc.enhanced.execution.enabled=true, \
          spark.network.timeout=300s, \
          spark.executor.heartbeatInterval=60s, \
          spark.speculation=true, \
          dataproc.gcsConnector.version=3.1.2, \
          dataproc.sparkBqConnector.version=0.42.3, \
          dataproc.profiling.enabled=true, \
          dataproc.profiling.name=dingoserverless" \
        -- \
        --spark.driver.log.level=INFO
}

# https://cloud.google.com/dataproc-serverless/docs/guides/native-query-execution#native_query_execution_properties
__nqe() {
        # spark.memory.offHeap.enabled=true
    gcloud dataproc batches submit spark \
        --project=$PROJECT_ID \
        --region=$REGION \
        --batch=$BATCH_ID \
        --class=GcpTest \
        --jars=$GCS_JAR_PATH \
        --deps-bucket=gs://$BUCKET_NAME/staging \
        --subnet=default \
        --version $RUNTIME \
        --history-server-cluster=$PHS_RESOURCE_NAME \
        --autotuning-scenarios=auto \
        --properties \
          "spark.executor.cores=4, \
          spark.executor.memory=5g, \
          spark.executor.memoryOverhead=4g, \
          spark.memory.offHeap.size=20g, \
          spark.driver.cores=4, \
          spark.driver.memory=25g, \
          spark.driver.memoryOverhead=4g, \
          spark.dynamicAllocation.enabled=true, \
          spark.dynamicAllocation.initialExecutors=2, \
          spark.dynamicAllocation.minExecutors=2, \
          spark.dynamicAllocation.maxExecutors=100, \
          spark.dynamicAllocation.executorAllocationRatio=1.0, \
          spark.decommission.maxRatio=0.3, \
          spark.reducer.fetchMigratedShuffle.enabled=true, \
          spark.dataproc.scaling.version=2, \
          spark.dataproc.driver.compute.tier=premium, \
          spark.dataproc.executor.compute.tier=premium, \
          spark.dataproc.driver.disk.tier=premium, \
          spark.dataproc.driver.disk.size=375g, \
          spark.dataproc.executor.disk.tier=premium, \
          spark.dataproc.executor.disk.size=375g, \
          spark.sql.adaptive.enabled=true, \
          spark.sql.adaptive.coalescePartitions.enabled=true, \
          spark.sql.adaptive.skewJoin.enabled=true, \
          spark.dataproc.enhanced.optimizer.enabled=true, \
          spark.dataproc.enhanced.execution.enabled=true, \
          spark.network.timeout=300s, \
          spark.executor.heartbeatInterval=60s, \
          spark.speculation=true, \
          dataproc.gcsConnector.version=3.1.2, \
          dataproc.sparkBqConnector.version=0.42.3, \
          dataproc.profiling.enabled=true, \
          dataproc.profiling.name=dingoserverless, \
          spark.dataproc.runtimeEngine=native" \
        -- \
        --spark.driver.log.level=INFO
}

__main() {
    if [ $# -eq 0 ]
    then
        __run_serverless
    else
        case $1 in
            serverless)
                __run_serverless
                ;;
            nqe)
                __nqe
                ;;
            *)
                __run_serverless
                ;;
        esac
    fi
}

__main $@
