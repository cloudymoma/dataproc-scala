# ⚡ Spark on Dataproc

[![CI](https://github.com/cloudymoma/dataproc-scala/actions/workflows/ci.yml/badge.svg)](https://github.com/cloudymoma/dataproc-scala/actions/workflows/ci.yml)

一个用于在 Google Cloud Dataproc 上运行 Apache Spark 作业的综合工具包，支持闪电引擎 (Lightning Engine) 和原生查询引擎 (Native Query Engine, NQE)。

## 📁 文件生成器（可选）

使用 [CSV 文件生成器](https://github.com/cloudymoma/csv_data_generator) 来生成大型文件。[filegen.py](filegen.py) 稍微有些慢。

## 🛠️ Make 命令

### 🏗️ 基础设施设置
- **`make histserver`** - 创建 [持久化历史服务器 (PHS)](https://cloud.google.com/dataproc/docs/concepts/jobs/history-server)
- **`make jobserver`** - 创建具有计算资源自动缩放的临时作业服务器，可通过 [autoscaling-policy.yml](autoscaling-policy.yml) 配置。可以关闭。

### 🔨 构建和运行
- **`make build_local`** - 使用 sbt 在本地交叉构建 Scala `2.12`（Cluster `2.3`）和 Scala `2.13`（Serverless `2.3`）JAR
- **`make build_mvn`** - 使用 Maven 在本地交叉构建 Scala `2.12` 和 `2.13` 两个 profile
- **`make build`** - 交叉构建 Scala `2.12` 和 `2.13` JAR 并上传至 GCS
- **`make run`** - 在临时集群（`2.3-debian12`，Spark `3.5.3`，Scala `2.12`）上运行作业
  - 支持 [闪电引擎](https://cloud.google.com/blog/products/data-analytics/introducing-lightning-engine-for-apache-spark?e=48754805) 和原生查询引擎

### ☁️ 无服务器执行
- **`make run_serverless`** - 在 Managed Spark Serverless **`2.3`**（Spark `3.5.3`，Scala `2.13`）**高级 (premium)** 层级运行批处理作业（闪电引擎）
  - 使用 N2 实例 + LocalSSD shuffle
- **`make run_serverless_std`** - 在 Managed Spark Serverless **`2.3`** **标准 (standard)** 层级运行批处理作业
  - 使用 E2 实例 + pd-standard shuffle
- **`make run_nqe`** - 在 Serverless **`2.3`** 上启用原生查询引擎运行（`spark.dataproc.lightningEngine.runtime=native`）
  - 使用高级层级 + LocalSSD shuffle + 原生执行引擎
  - 需要使用 `make qualify` 进行兼容性检查

### ✅ 作业兼容性
- **`make qualify`** - 针对 Spark 事件日志运行资格验证工具，检查 **`NQE`** 的作业兼容性
  - *注意：* 如果直接下载 `https://storage.googleapis.com/qualification-tool/` 返回 403，Google Cloud 官方推荐使用 Serverless PySpark 资格验证作业（`gs://qualification-tool/performance-boost-qualification.py` 与 `gs://qualification-tool/dataproc-perfboost-qualification-1.2.jar`）。

## ⚙️ 配置

### 🎛️ Dataproc 集群引擎设置
```bash
# 标准引擎（在 `make jobserver` 创建集群时生效）
export DATAPROC_ENGINE=default

# 闪电引擎（spark.sh 默认值，在 `make jobserver` 创建集群时生效）
export DATAPROC_ENGINE=lightning

# 在 `make run` 提交作业时按作业启用原生查询引擎（仅限闪电引擎集群）
export ENABLE_NQE=true
```

> **注意：** `DATAPROC_ENGINE` 在创建集群（`make jobserver`）时固定（闪电引擎需要 `2.3-debian12` 及以上镜像）。`make run` 在 `ENABLE_NQE=true` 时会检查目标集群的实际引擎，若非闪电引擎集群将直接报错退出。脚本仍自动兼容旧环境变量 `DATAPROC_TIER=standard|premium`。

### 📝 作业配置
在 [`spark.sh`](spark.sh) 中手动调整作业配置以适应您的特定需求。使用 NQE 时，始终先运行资格验证工具以确保兼容性。

## 📚 附加资源

- **BigQuery 集成：** 在 [BigQuery](https://cloud.google.com/bigquery) 中以存储过程形式运行 [Spark 无服务器](https://cloud.google.com/products/serverless-spark) - [指南](https://github.com/cloudymoma/gcp-playgroud-public/blob/master/BigQuery/bq_spark.md)

## 🔬 FIO（灵活 I/O 测试器）集成

### 🔧 从源码构建 FIO

#### 🏗️ 基本构建
```bash
git clone https://github.com/axboe/fio.git
cd fio
./configure --build-static
make
```

#### 🔧 构建故障排除

**针对虚拟化环境 (QEMU)：**
```bash
./configure --build-static --disable-optimizations
```

**最小轻量化配置：**
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

运行 `make` 后，`fio` 二进制文件将在您的项目目录中可用。

#### 🚀 部署到 GCS
```bash
gcloud storage cp fio gs://dingoproc/fio_linux_x86
```

查看 [GcpTest.scala#L277-L295](https://github.com/cloudymoma/dataproc-scala/blob/main/src/main/scala/GcpTest.scala#L277-L295) 了解运行时下载到 Spark workers 的方法。

### 📊 FIO 性能测试速查表

#### 🔨 基本测试

**随机读取测试**
```bash
fio --name=randread --ioengine=libaio --iodepth=16 --rw=randread --bs=4k --direct=0 --size=512M --numjobs=4 --runtime=240 --group_reporting
```

**随机写入测试** (总计 2GB：4 个作业 × 512MB)
```bash
fio --name=randwrite --ioengine=libaio --iodepth=1 --rw=randwrite --bs=4k --direct=0 --size=512M --numjobs=4 --runtime=240 --group_reporting
```

**混合读写测试** (75% 读取，25% 写入)
```bash
fio --randrepeat=1 --ioengine=libaio --direct=1 --gtod_reduce=1 --name=test --filename=random_read_write.fio --bs=4k --iodepth=64 --size=4G --readwrite=randrw --rwmixread=75
```

#### ⏩ 顺序性能测试

**顺序读取** (8K 块，直接 I/O)
```bash
fio --name=seqread --rw=read --direct=1 --ioengine=libaio --bs=8k --numjobs=8 --size=1G --runtime=600 --group_reporting
```

**顺序写入** (32K 块，直接 I/O)
```bash
fio --name=seqwrite --rw=write --direct=1 --ioengine=libaio --bs=32k --numjobs=4 --size=2G --runtime=600 --group_reporting
```

#### 🎲 随机性能测试

**随机读取** (8K 块，直接 I/O)
```bash
fio --name=randread --rw=randread --direct=1 --ioengine=libaio --bs=8k --numjobs=16 --size=1G --runtime=600 --group_reporting
```

**随机写入** (64K 块，直接 I/O)
```bash
fio --name=randwrite --rw=randwrite --direct=1 --ioengine=libaio --bs=64k --numjobs=8 --size=512m --runtime=600 --group_reporting
```

**混合随机读写** (90% 读取，10% 写入)
```bash
fio --name=randrw --rw=randrw --direct=1 --ioengine=libaio --bs=16k --numjobs=8 --rwmixread=90 --size=1G --runtime=600 --group_reporting
```

#### 🚀 高级测试场景

**基于时间的混合工作负载** (70% 读取，30% 写入，5 分钟持续时间)
- 创建 8 个文件（每个 512MB），使用 64K 块大小
- 无论是否完成都精确运行 5 分钟
```bash
fio --name=randrw --ioengine=libaio --iodepth=1 --rw=randrw --bs=64k --direct=1 --size=512m --numjobs=8 --runtime=300 --group_reporting --time_based --rwmixread=70
```

**数据库模拟** (3:1 读写比例，典型数据库工作负载)
- 4GB 文件，4KB 操作
- 75% 读取，25% 写入分割
- 64 个并发操作
```bash
fio --randrepeat=1 --ioengine=libaio --direct=1 --gtod_reduce=1 --name=test --filename=test --bs=4k --iodepth=64 --size=4G --readwrite=randrw --rwmixread=75
```

**纯随机读取性能**
```bash
fio --randrepeat=1 --ioengine=libaio --direct=1 --gtod_reduce=1 --name=test --filename=test --bs=4k --iodepth=64 --size=4G --readwrite=randread
```

**纯随机写入性能**
```bash
fio --randrepeat=1 --ioengine=libaio --direct=1 --gtod_reduce=1 --name=test --filename=test --bs=4k --iodepth=64 --size=4G --readwrite=randwrite
```