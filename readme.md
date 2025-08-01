# ⚡ Spark on Dataproc

[![CI](https://github.com/cloudymoma/dataproc-scala/actions/workflows/ci.yml/badge.svg)](https://github.com/cloudymoma/dataproc-scala/actions/workflows/ci.yml)

[中文](readme_cn.md)

A comprehensive toolkit for running Apache Spark jobs on Google Cloud Dataproc with support for Lightning Engine and Native Query Engine (NQE).

## 📁 File Generator (optional)

Use the [CSV file generator](https://github.com/cloudymoma/csv_data_generator) for large file generation. [filegen.py](filegen.py) is a bit slow.

## 🛠️ Make Commands

### 🏗️ Infrastructure Setup
- **`make histserver`** - Create a [Persistent History Server (PHS)](https://cloud.google.com/dataproc/docs/concepts/jobs/history-server)
- **`make jobserver`** - Create an ephemeral job server with computing resource autoscaling, this is configurable through [autoscaling-policy.yml](autoscaling-policy.yml). Can be turned off.

### 🔨 Build and Run
- **`make build`** - Build the Scala source code
- **`make run`** - Run job on ephemeral cluster (highly customizable)
  - Supports [Lightning Engine](https://cloud.google.com/blog/products/data-analytics/introducing-lightning-engine-for-apache-spark?e=48754805) and Native Query Engine

### ☁️ Serverless Execution
- **`make run_serverless`** - Run batch job in Dataproc Serverless **premium** mode
  - Uses N2 instances + LocalSSD shuffle
- **`make run_serverless_std`** - Run batch job in Dataproc Serverless **standard** mode
  - Uses E2 instances + pd-standard shuffle
- **`make run_nqe`** - Run with Native Query Engine enabled
  - Uses N2 + LocalSSD shuffle + native execution engine
  - Requires compatibility check with `make qualify`

### ✅ Job Compatibility
- **`make qualify`** - Run qualification tool against Spark event logs to check job compatibility for **`NQE`**

## ⚙️ Configuration

### 🎛️ Dataproc Cluster Tier Settings
```bash
# Default tier (standard)
export DATAPROC_TIER=standard

# Premium tier (Lightning Engine)
export DATAPROC_TIER=premium

# Enable Native Query Engine (Premium tier only)
export ENABLE_NQE=true
```

> **Note:** Native Query Engine is only available on Premium tier clusters.

### 📝 Job Configuration
Manually adjust job configuration in [`spark.sh`](spark.sh) to fit your specific needs. When using NQE, always run the qualification tool first to ensure compatibility.

## 📚 Additional Resources

- **BigQuery Integration:** Run [Spark Serverless](https://cloud.google.com/products/serverless-spark) in [BigQuery](https://cloud.google.com/bigquery) as a stored procedure - [Guide](https://github.com/cloudymoma/gcp-playgroud-public/blob/master/BigQuery/bq_spark.md)

## 🔬 FIO (Flexible I/O Tester) Integration

### 🔧 Building FIO from Source

#### 🏗️ Basic Build
```bash
git clone https://github.com/axboe/fio.git
cd fio
./configure --build-static
make
```

#### 🔧 Troubleshooting Builds

**For virtualized environments (QEMU):**
```bash
./configure --build-static --disable-optimizations
```

**Minimal lightweight configuration:**
```bash
./configure --build-static \
    --disable-numa \
    --disable-rdma \
    --disable-gfapi \
    --disable-libhdfs \
    --disable-pmem \
    --disable-gfio \
    --disable-libiscsi \
    --disable-rados \
    --disable-rbd \
    --disable-zlib
```

After running `make`, the `fio` binary will be available in your project directory.

#### 🚀 Deployment to GCS
```bash
gcloud storage cp fio gs://dingoproc/fio_linux_x86
```

See [GcpTest.scala#L277-L295](https://github.com/cloudymoma/dataproc-scala/blob/main/src/main/scala/GcpTest.scala#L277-L295) for runtime download to Spark workers.

### 📊 FIO Performance Testing Cheat Sheet

#### 🔨 Basic Tests

**Random Read Test**
```bash
fio --name=randread --ioengine=libaio --iodepth=16 --rw=randread --bs=4k --direct=0 --size=512M --numjobs=4 --runtime=240 --group_reporting
```

**Random Write Test** (2GB total: 4 jobs × 512MB)
```bash
fio --name=randwrite --ioengine=libaio --iodepth=1 --rw=randwrite --bs=4k --direct=0 --size=512M --numjobs=4 --runtime=240 --group_reporting
```

**Mixed Read/Write Test** (75% read, 25% write)
```bash
fio --randrepeat=1 --ioengine=libaio --direct=1 --gtod_reduce=1 --name=test --filename=random_read_write.fio --bs=4k --iodepth=64 --size=4G --readwrite=randrw --rwmixread=75
```

#### ⏩ Sequential Performance Tests

**Sequential Reads** (8K blocks, Direct I/O)
```bash
fio --name=seqread --rw=read --direct=1 --ioengine=libaio --bs=8k --numjobs=8 --size=1G --runtime=600 --group_reporting
```

**Sequential Writes** (32K blocks, Direct I/O)
```bash
fio --name=seqwrite --rw=write --direct=1 --ioengine=libaio --bs=32k --numjobs=4 --size=2G --runtime=600 --group_reporting
```

#### 🎲 Random Performance Tests

**Random Reads** (8K blocks, Direct I/O)
```bash
fio --name=randread --rw=randread --direct=1 --ioengine=libaio --bs=8k --numjobs=16 --size=1G --runtime=600 --group_reporting
```

**Random Writes** (64K blocks, Direct I/O)
```bash
fio --name=randwrite --rw=randwrite --direct=1 --ioengine=libaio --bs=64k --numjobs=8 --size=512m --runtime=600 --group_reporting
```

**Mixed Random Read/Write** (90% read, 10% write)
```bash
fio --name=randrw --rw=randrw --direct=1 --ioengine=libaio --bs=16k --numjobs=8 --rwmixread=90 --size=1G --runtime=600 --group_reporting
```

#### 🚀 Advanced Testing Scenarios

**Time-based Mixed Workload** (70% read, 30% write, 5-minute duration)
- Creates 8 files (512MB each) with 64K block size
- Runs for exactly 5 minutes regardless of completion
```bash
fio --name=randrw --ioengine=libaio --iodepth=1 --rw=randrw --bs=64k --direct=1 --size=512m --numjobs=8 --runtime=300 --group_reporting --time_based --rwmixread=70
```

**Database Simulation** (3:1 read/write ratio, typical database workload)
- 4GB file with 4KB operations
- 75% read, 25% write split
- 64 concurrent operations
```bash
fio --randrepeat=1 --ioengine=libaio --direct=1 --gtod_reduce=1 --name=test --filename=test --bs=4k --iodepth=64 --size=4G --readwrite=randrw --rwmixread=75
```

**Pure Random Read Performance**
```bash
fio --randrepeat=1 --ioengine=libaio --direct=1 --gtod_reduce=1 --name=test --filename=test --bs=4k --iodepth=64 --size=4G --readwrite=randread
```

**Pure Random Write Performance**
```bash
fio --randrepeat=1 --ioengine=libaio --direct=1 --gtod_reduce=1 --name=test --filename=test --bs=4k --iodepth=64 --size=4G --readwrite=randwrite
```
