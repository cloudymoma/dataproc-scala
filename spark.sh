#!/bin/bash -ex

export PHS_CLUSTER_NAME=dingohist
export REGION=us-central1
export ZONE=$REGION-b
export GCS_BUCKET=dingoproc
export PROJECT_NAME=du-hast-mich
export STAGING_BUCKET=$GCS_BUCKET
export TEMP_BUCKET=$GCS_BUCKET

export JOB_CLUSTER_NAME=dingojob
export IMG_VERSION=2.3-debian12
export JOB_MASTER_MACHINE_TYPE=c2d-standard-4
export JOB_WORKER_MACHINE_TYPE=c2d-standard-4
export MAX_IDLE=1h

# default engine setup
# export DATAPROC_TIER=standard

# Lightning Engine setup
export DATAPROC_TIER=premium
export ENALBE_NQE=false # only for premium tier

export GCS_JAR_PATH="gs://dingoproc/jars/gcptest_2.12-0.1.0.jar"
export GCS_FATJAR_PATH="gs://dingoproc/jars/gcptest-assembly-0.1.0.jar"
export OUTPUT_PATH="gs://dingoproc/scala_output"

pwd=$(pwd)

__usage() {
    echo "Usage: ./spark.sh {histserver,jobserver,job}"
}

__hist_server() {
    gcloud dataproc clusters create $PHS_CLUSTER_NAME \
        --enable-component-gateway \
        --region=${REGION} --zone=$ZONE \
        --image-version=${IMG_VERSION} \
        --single-node \
        --master-machine-type=n4-standard-4 \
        --master-boot-disk-size=128GB \
        --bucket=$STAGING_BUCKET \
        --temp-bucket=$TEMP_BUCKET \
        --properties=yarn:yarn.nodemanager.remote-app-log-dir=gs://$GCS_BUCKET/yarn-logs \
        --properties=spark:spark.eventLog.enabled=true \
        --properties=spark:spark.eventLog.dir=gs://$GCS_BUCKET/events/spark-job-history \
        --properties=spark:spark.eventLog.rolling.enabled=true \
        --properties=spark:spark.eventLog.rolling.maxFileSize=128m \
        --properties=spark:spark.history.fs.logDirectory=gs://$GCS_BUCKET/events/spark-job-history \
        --project=$PROJECT_NAME
}

__define_auto_scale_policy() {
    gcloud dataproc autoscaling-policies import balanced-scaling-policy \
        --source=$pwd/autoscaling-policy.yml \
        --region=$REGION
}

__job_server() {
        # --secondary-worker-machine-types=t2d-standard-2 \
        # --properties=dataproc:efm.spark.shuffle=primary-worker \
    gcloud dataproc clusters create $JOB_CLUSTER_NAME \
        --enable-component-gateway \
        --region=$REGION --zone=$ZONE \
        --image-version=${IMG_VERSION} \
        --max-idle=$MAX_IDLE \
        --bucket=$STAGING_BUCKET \
        --temp-bucket=$TEMP_BUCKET \
        --tier=$DATAPROC_TIER \
        --master-machine-type=$JOB_MASTER_MACHINE_TYPE \
        --num-masters=1 \
        --master-boot-disk-size=128GB \
        --master-boot-disk-type=pd-balanced \
        --num-master-local-ssds=1 \
        --master-local-ssd-interface=NVME \
        --autoscaling-policy=balanced-scaling-policy \
        --worker-machine-type=$JOB_WORKER_MACHINE_TYPE \
        --num-workers=2 \
        --worker-boot-disk-size=500GB \
        --worker-boot-disk-type=pd-ssd \
        --num-worker-local-ssds=1 \
        --worker-local-ssd-interface=NVME \
        --secondary-worker-type=spot \
        --num-secondary-workers=2 \
        --secondary-worker-boot-disk-size=256GB \
        --secondary-worker-boot-disk-type=pd-balanced \
        --num-secondary-worker-local-ssds=1 \
        --secondary-worker-local-ssd-interface=NVME \
        --properties=yarn:yarn.nodemanager.remote-app-log-dir=gs://$GCS_BUCKET/yarn-logs \
        --properties=spark:spark.eventLog.enabled=true \
        --properties=spark:spark.eventLog.dir=gs://$GCS_BUCKET/events/spark-job-history \
        --properties=spark:spark.eventLog.rolling.enabled=true \
        --properties=spark:spark.eventLog.rolling.maxFileSize=128m \
        --properties=spark:spark.history.fs.logDirectory=gs://$GCS_BUCKET/events/spark-job-history \
        --properties=spark:spark.history.fs.gs.outputstream.type=FLUSHABLE_COMPOSITE \
        --properties=spark:spark.history.fs.gs.outputstream.sync.min.interval.ms=1000ms \
        --properties=spark:spark.dataproc.enhanced.optimizer.enabled=true \
        --properties=spark:spark.dataproc.enhanced.execution.enabled=true \
        --properties=dataproc:dataproc.cluster.caching.enabled=true \
        --project=$PROJECT_NAME
}

__job_properties() {
    if [ "$ENALBE_NQE" = "true" ]; then
        echo "spark.dataproc.engine=lightningEngine,
          spark.dataproc.lightningEngine.runtime=native,
          spark.executor.cores=4,
          spark.executor.memory=2g,
          spark.executor.memoryOverhead=1g,
          spark.memory.offHeap.size=10g,
          spark.driver.cores=4,
          spark.driver.memory=12g,
          spark.driver.memoryOverhead=1g,
          spark.dynamicAllocation.enabled=true,
          spark.dynamicAllocation.initialExecutors=2,
          spark.dynamicAllocation.minExecutors=2,
          spark.dynamicAllocation.maxExecutors=100,
          spark.dynamicAllocation.executorAllocationRatio=1.0,
          spark.decommission.maxRatio=0.3,
          spark.reducer.fetchMigratedShuffle.enabled=true"
    else
        local properties="spark.executor.cores=4,
          spark.executor.memory=12g,
          spark.executor.memoryOverhead=512m,
          spark.driver.cores=4,
          spark.driver.memory=12g,
          spark.driver.memoryOverhead=512m,
          spark.dynamicAllocation.enabled=true,
          spark.dynamicAllocation.initialExecutors=2,
          spark.dynamicAllocation.minExecutors=2,
          spark.dynamicAllocation.maxExecutors=100,
          spark.dynamicAllocation.executorAllocationRatio=1.0,
          spark.decommission.maxRatio=0.3,
          spark.reducer.fetchMigratedShuffle.enabled=true"
        if [ "$DATAPROC_TIER" = "premium" ]; then
            properties="spark.dataproc.engine=lightningEngine,$properties"
        fi
        echo "$properties"
    fi
}

__job() {
    gcloud dataproc jobs submit spark \
        --region=$REGION \
        --cluster=$JOB_CLUSTER_NAME \
        --class=GcpTest \
        --jars=$GCS_FATJAR_PATH \
        --properties="$(__job_properties | tr -d '[:space:]')" \
        -- \
        $OUTPUT_PATH
}

__main() {
    if [ $# -eq 0 ]
    then
        __usage
    else
        case $1 in
            histserver)
                __hist_server
                __define_auto_scale_policy
                ;;
            policy|p)
                __define_auto_scale_policy
                ;;
            jobserver)
                __job_server
                ;;
            job)
                __job
                ;;
            *)
                __usage
                ;;
        esac
    fi
}

__main $@
