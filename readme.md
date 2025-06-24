### Spark on Dataproc

use [csv file generator](https://github.com/cloudymoma/csv_data_generator) from
here for better performance.

`make histserver` to create
a [PHS](https://cloud.google.com/dataproc/docs/concepts/jobs/history-server)

`make jobserver` to create a ephemeral job server with autocaling

`make build` - build the job scala source code

`make run` - run job on ephemeral job serser

`make run_serverless` - run batch job in dataproc serverless mode

`make run_nqe` - run batch job in dataproc serverless mode but native query
engine for boosted performance. run the qualification tool against the spark
event logs dir to check the compatibilities of your jobs `make qualify`.

### build `fio` from sourcer

```shell
git clone https://github.com/axboe/fio.git
cd fio

./configure --build-static
make
```

In some virtualized or emulated environments, such as QEMU, default compiler optimizations might cause issues. If you encounter unexpected behavior with your static build, you can try disabling optimizations during the configuration step:

```shell
./configure --build-static --disable-optimizations
```

Or a minimal configuration for a general-purpose, lightweight fio binary is:

```shell
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

anyway, after `make`, you should see `fio` binary right in your project/current folder.

I have copied to GCS and load into my spark job at runtime

```
gcloud storage cp fio gs://dingoproc/fio_linux_x86
```

[download to spark worker](https://github.com/cloudymoma/dataproc-scala/blob/main/src/main/scala/GcpTest.scala#L271-L289)

#### fio cheatsheet

 Read Test
 ```
fio --name=randread --ioengine=libaio --iodepth=16 --rw=randread --bs=4k --direct=0 --size=512M --numjobs=4 --runtime=240 --group_reporting
```

writes a total 2GB files [4 jobs x 512 MB = 2GB] running 4 processes at a time:
```
fio --name=randwrite --ioengine=libaio --iodepth=1 --rw=randwrite --bs=4k --direct=0 --size=512M --numjobs=4 --runtime=240 --group_reporting
```

Read Write Performance Test
 ```
fio --randrepeat=1 --ioengine=libaio --direct=1 --gtod_reduce=1 --name=test --filename=random_read_write.fio --bs=4k --iodepth=64 --size=4G --readwrite=randrw --rwmixread=75
 ```

Sequential Reads – Async mode – 8K block size – Direct IO – 100% Reads
```
fio --name=seqread --rw=read --direct=1 --ioengine=libaio --bs=8k --numjobs=8 --size=1G --runtime=600  --group_reporting
```

Sequential Writes – Async mode – 32K block size – Direct IO – 100% Writes
```
fio --name=seqwrite --rw=write --direct=1 --ioengine=libaio --bs=32k --numjobs=4 --size=2G --runtime=600 --group_reporting
```

Random Reads – Async mode – 8K block size – Direct IO – 100% Reads
```
fio --name=randread --rw=randread --direct=1 --ioengine=libaio --bs=8k --numjobs=16 --size=1G --runtime=600 --group_reporting
```

Random Writes – Async mode – 64K block size – Direct IO – 100% Writes
```
fio --name=randwrite --rw=randwrite --direct=1 --ioengine=libaio --bs=64k --numjobs=8 --size=512m --runtime=600 --group_reporting
```

Random Read/Writes – Async mode – 16K block size – Direct IO – 90% Reads/10% Writes
```
fio --name=randrw --rw=randrw --direct=1 --ioengine=libaio --bs=16k --numjobs=8 --rwmixread=90 --size=1G --runtime=600 --group_reporting
```

creates 8 files (numjobs=8) each with size 512MB (size) at 64K block size (bs=64k) and will perform random read/write (rw=randrw) with the mixed workload of 70% reads and 30% writes. 
The job will run for full 5 minutes (runtime=300 & time_based) even if the files were created and read/written.
``` 
fio --name=randrw --ioengine=libaio --iodepth=1 --rw=randrw --bs=64k --direct=1 --size=512m --numjobs=8 --runtime=300 --group_reporting --time_based --rwmixread=70
 ```

compare disk performance with a simple 3:1 4K read/write test
creates a 4 GB file and perform 4KB reads and writes using a 75%/25% split within the file, with 64 operations running at a time. The 3:1 ratio represents a typical database.
```
fio --randrepeat=1 --ioengine=libaio --direct=1 --gtod_reduce=1 --name=test --filename=test --bs=4k --iodepth=64 --size=4G --readwrite=randrw --rwmixread=75
```

Random read performance
```
fio --randrepeat=1 --ioengine=libaio --direct=1 --gtod_reduce=1 --name=test --filename=test --bs=4k --iodepth=64 --size=4G --readwrite=randread
```

Random write performance
```
fio --randrepeat=1 --ioengine=libaio --direct=1 --gtod_reduce=1 --name=test --filename=test --bs=4k --iodepth=64 --size=4G --readwrite=randwrite
```