pwd := $(shell pwd)

LOCAL_JAR_PATH := /usr/local/google/home/binwu/workspace/customers/yeahmobi/gcptest/target/scala-2.12/gcptest_2.12-0.1.0.jar
GCS_JAR_PATH := gs://dingoproc/jars/gcptest_2.12-0.1.0.jar

LOCAL_FATJAR_PATH := /usr/local/google/home/binwu/workspace/customers/yeahmobi/gcptest/target/scala-2.12/gcptest-assembly-0.1.0.jar
GCS_FATJAR_PATH := gs://dingoproc/jars/gcptest-assembly-0.1.0.jar

GCS_SPARK_LOG_DIR := gs://dingoproc/events/spark-job-history
SERVICE_ACC := /usr/local/google/home/binwu/workspace/google/sa.json

build:
	sbt clean package assembly
	gcloud storage cp $(LOCAL_JAR_PATH) $(GCS_JAR_PATH)
	gcloud storage cp $(LOCAL_FATJAR_PATH) $(GCS_FATJAR_PATH)

run_serverless: 
	$(pwd)/run.sh serverless

run_nqe:
	$(pwd)/run.sh nqe

histserver: 
	$(pwd)/spark.sh histserver

jobserver: 
	$(pwd)/spark.sh jobserver

run:
	$(pwd)/spark.sh job

run_serverless_std: 
	$(pwd)/run.sh serverless-standard

qualify:
	$(pwd)/run_qualification_tool.sh -f $(GCS_SPARK_LOG_DIR) \
		-k $(SERVICE_ACC) \
		-x 32g -t 16 \
		-o perfboost-output

.PHONY: build run_serverless run_nqe run histserver jobserver qualify run_serverless_std
