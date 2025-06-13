pwd := $(shell pwd)
LOCAL_JAR_PATH := /usr/local/google/home/binwu/workspace/customers/yeahmobi/gcptest/target/scala-2.12/gcptest_2.12-0.1.0.jar
GCS_JAR_PATH := gs://dingoproc/jars/gcptest_2.12-0.1.0.jar

build:
	sbt clean package
	gcloud storage cp $(LOCAL_JAR_PATH) $(GCS_JAR_PATH)

run_serverless: 
	$(pwd)/run.sh

histserver: 
	$(pwd)/spark.sh histserver

jobserver: 
	$(pwd)/spark.sh jobserver

run:
	$(pwd)/spark.sh job

.PHONY: build run_serverless run histserver jobserver
