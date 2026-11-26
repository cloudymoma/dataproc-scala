pwd := $(shell pwd)

# Scala 2.12 artifacts for Managed Spark Cluster 2.3
LOCAL_JAR_212_PATH := $(pwd)/target/scala-2.12/gcptest_2.12-0.1.0.jar
GCS_JAR_212_PATH := gs://dingoproc/jars/gcptest_2.12-0.1.0.jar

LOCAL_FATJAR_212_PATH := $(pwd)/target/scala-2.12/gcptest_2.12-0.1.0-assembly.jar
GCS_FATJAR_212_PATH := gs://dingoproc/jars/gcptest_2.12-0.1.0-assembly.jar

# Scala 2.13 artifacts for Managed Spark Serverless 2.3
LOCAL_JAR_213_PATH := $(pwd)/target/scala-2.13/gcptest_2.13-0.1.0.jar
GCS_JAR_213_PATH := gs://dingoproc/jars/gcptest_2.13-0.1.0.jar

LOCAL_FATJAR_213_PATH := $(pwd)/target/scala-2.13/gcptest_2.13-0.1.0-assembly.jar
GCS_FATJAR_213_PATH := gs://dingoproc/jars/gcptest_2.13-0.1.0-assembly.jar

GCS_SPARK_LOG_DIR := gs://dingoproc/events/spark-job-history
SERVICE_ACC := /usr/local/google/home/binwu/workspace/google/sa.json

build_local:
	sbt +clean +package +assembly

build_mvn:
	mvn clean package -DskipTests -Pscala-2.12
	mvn package -DskipTests -Pscala-2.13

build: build_local
	gcloud storage cp $(LOCAL_JAR_212_PATH) $(GCS_JAR_212_PATH)
	gcloud storage cp $(LOCAL_FATJAR_212_PATH) $(GCS_FATJAR_212_PATH)
	gcloud storage cp $(LOCAL_JAR_213_PATH) $(GCS_JAR_213_PATH)
	gcloud storage cp $(LOCAL_FATJAR_213_PATH) $(GCS_FATJAR_213_PATH)

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

.PHONY: build build_local build_mvn run_serverless run_nqe run histserver jobserver qualify run_serverless_std
