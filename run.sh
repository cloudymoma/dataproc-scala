#!/bin/bash

# --- Configuration Variables ---
# Your GCP Project ID
export PROJECT_ID=$(gcloud config get-value project)

# The GCP region to run the job in. Choose one near you or your data.
# Since you are in Beijing, asia-east2 (Hong Kong) or asia-northeast1 (Tokyo) are good choices.
export REGION="us-central1" # Example: Changhua County, Taiwan

# A unique name for this specific batch job run
export BATCH_ID="fake-data-generator-$(date +%Y%m%d-%H%M%S)"

LOCAL_JAR_PATH=/usr/local/google/home/binwu/workspace/customers/yeahmobi/gcptest/target/scala-2.13/gcptest_2.13-0.1.0.jar
# The GCS path to your JAR, defined in the previous step
GCS_JAR_PATH="gs://dingoproc/jars/gcptest_2.13-0.1.0.jar"

# The GCS bucket for staging dependencies and logs
BUCKET_NAME="dingoproc"

sbt clean package

gcloud storage cp $LOCAL_JAR_PATH $GCS_JAR_PATH

# --- The gcloud Command ---
gcloud dataproc batches submit spark \
    --project=$PROJECT_ID \
    --region=$REGION \
    --batch=$BATCH_ID \
    --class=GcpTest \
    --jars=$GCS_JAR_PATH \
    --deps-bucket=gs://$BUCKET_NAME/staging \
    --subnet=default \
    -- \
    --spark.driver.log.level=INFO
