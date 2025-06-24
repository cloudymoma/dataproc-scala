import org.apache.spark.SparkConf
import org.apache.spark.sql.{SparkSession, SaveMode}
import org.apache.spark.sql.functions._
import org.apache.spark.util.LongAccumulator // Added for accumulators
import org.apache.spark.sql.execution.datasources.SQLHadoopMapReduceCommitProtocol // For metrics, though might not be directly used for custom listeners
import org.apache.spark.scheduler.{SparkListener, SparkListenerTaskEnd} // For listening to task events
import scala.sys.process._
import org.json4s._
import org.json4s.native.JsonMethods._

object GcpTest {

  // Implicit formats for json4s parsing
  implicit val formats = DefaultFormats

	def run(Day: String): Unit ={
		val conf = new SparkConf().setAppName("GCS FileIO Test")
//		conf.set("spark.sql.hive.metastore.uris", "grpc://dataproc-metadata-hive-34c3cfdd-vdbq7vognq-uk.a.run.app:443")
//		conf.set("spark.sql.hive.metastore.rpc", "grpc")
//		conf.set("spark.sql.catalogImplementation", "hive")
        conf.set(
          "spark.hadoop.mapreduce.outputcommitter.factory.class",
          "org.apache.hadoop.mapreduce.lib.output.DataprocFileOutputCommitterFactory")
        // The Dataproc file output committer must set spark.hadoop.mapreduce.fileoutputcommitter.marksuccessfuljobs=false to avoid conflicts between success marker files created during concurrent writes.
        conf.set(
          "spark.hadoop.mapreduce.fileoutputcommitter.marksuccessfuljobs",
          "false")
		val spark = SparkSession.builder.config(conf).enableHiveSupport().getOrCreate()

        import spark.implicits._

        // -------------------- Task 1 GCS write single file

        /*
        val fakeDataDF = spark.range(10) 
          .withColumn("uid", expr("uuid()")) 
          .withColumn("max_days", (rand() * 100 + 1).cast("int")) 
          .select("uid", "max_days") 
          */

        val sqlQuery = """
          WITH generated_numbers AS (
            SELECT explode(sequence(1, 1000000)) AS n
          )
          SELECT
            uuid() AS uid,
            CAST(floor(rand() * 100) + 1 AS INT) AS max_days
          FROM generated_numbers
          ORDER BY max_days desc
          LIMIT 10
        """
        val fakeDataDF = spark.sql(sqlQuery)

        println("Generated data using the DataFrame API:")
        fakeDataDF.show()
        fakeDataDF.printSchema()

		fakeDataDF
          .repartition(1)
          .write
          .mode(SaveMode.Overwrite)
          .orc("gs://dingoproc/scala_output")

        // -------------- Task 2 GCS throughput
        println("\nStarting GCS read/write task...")

        val inputGcsPath = "gs://dingoproc/largecsv/input.csv"
        val outputGcsPath = "gs://dingoproc/largecsv/output.csv"

        // Accumulators for metrics
        val bytesReadAccumulator = spark.sparkContext.longAccumulator("bytesRead")
        val bytesWrittenAccumulator = spark.sparkContext.longAccumulator("bytesWritten")

        val startTime = System.nanoTime()

        // Read data from GCS
        println(s"Reading data from $inputGcsPath")
        val gcsDataDF = spark.read.format("csv").option("header", "true").load(inputGcsPath)
        
        gcsDataDF.cache() // Cache to ensure it's read
        val rowCount = gcsDataDF.count()
        println(s"Finished reading. Number of rows: $rowCount")
        
        // Write data back to GCS
        println(s"Writing data to $outputGcsPath")
        gcsDataDF.write.mode(SaveMode.Overwrite).format("csv").option("header", "true").save(outputGcsPath)
        println("Finished writing data to GCS.")

        val endTime = System.nanoTime()
        val durationSeconds = (endTime - startTime) / 1e9d

        println(s"\n--- GCS Read/Write Task Metrics ---")
        println(f"Time taken: $durationSeconds%.2f seconds")
        
        val logicalPlan = gcsDataDF.queryExecution.logical
        val stats = gcsDataDF.queryExecution.analyzed.stats
        val sizeInBytes = stats.sizeInBytes
        if (sizeInBytes > 0) {
            bytesReadAccumulator.add(sizeInBytes.toLong) // Approximate bytes read
        }

        println(s"Approximate Bytes Read (based on logical plan stats): ${bytesReadAccumulator.value} bytes")
        println(s"Bytes Written (placeholder, ideally from listeners or GCS API): ${bytesWrittenAccumulator.value} bytes (Note: This value might be 0 or inaccurate without a proper metrics collection setup for GCS writes)")
        println(s"------------------------------------")

        println("==================================================")
        println("              CPU Information")
        println("==================================================")
        printCpuInfo()

        println("\n==================================================")
        println("       Prime Number Computation (1 to Int.MaxValue)")
        println("==================================================")
        computePrimes(spark)

        println("\n==================================================")
        println("      Disk Information and I/O Benchmark")
        println("==================================================")
        printDiskInfo()
        testDiskIo()

		spark.stop()
	}

  def printCpuInfo(): Unit = {
    try {
      val result = "lscpu".!!
      println(result)
    } catch {
      case e: Exception => println(s"Could not retrieve CPU information: ${e.getMessage}")
    }
  }

  def computePrimes(spark: SparkSession): Unit = {
    val upperLimit = Int.MaxValue
    val sc = spark.sparkContext

    val startTime = System.nanoTime()

    // Step 1: Find primes up to sqrt(upperLimit) on the driver
    val sqrtLimit = Math.sqrt(upperLimit).toInt
    val initialPrimes = sieveOfEratosthenes(sqrtLimit)
    val broadcastPrimes = sc.broadcast(initialPrimes)

    // Step 2: Distribute the numbers to be checked
    val numbers = sc.parallelize(2L to upperLimit, 200) // Partitions can be increased for larger clusters

    // Step 3: Filter out multiples of the initial primes
    val primeCount = numbers.filter { n =>
      val localPrimes = broadcastPrimes.value
      var isPrime = true
      var i = 0
      // Efficiently check for divisibility
      while (i < localPrimes.length && localPrimes(i) * localPrimes(i) <= n) {
        if (n % localPrimes(i) == 0) {
          isPrime = false
          i = localPrimes.length // Exit loop early
        }
        i += 1
      }
      isPrime
    }.count()

    val endTime = System.nanoTime()
    val durationInSeconds = (endTime - startTime) / 1e9d
    println(f"Found $primeCount%,d prime numbers up to $upperLimit%,d.")
    println(f"Time taken for prime computation: $durationInSeconds%.2f seconds.")
  }

  def sieveOfEratosthenes(n: Int): Array[Int] = {
    val isPrime = Array.fill(n + 1)(true)
    isPrime(0) = false
    isPrime(1) = false
    for (p <- 2 to Math.sqrt(n).toInt) {
      if (isPrime(p)) {
        for (i <- p * p to n by p) {
          isPrime(i) = false
        }
      }
    }
    (2 to n).filter(isPrime).toArray
  }

  def printDiskInfo(): Unit = {
    try {
      val result = "lsblk --json".!!
      val parsedJson = parse(result)
      val blockDevices = (parsedJson \ "blockdevices").extract[List[JValue]]
      println("Disk Information:")
      for (device <- blockDevices) {
        val name = (device \ "name").extractOpt[String].getOrElse("N/A")
        val size = (device \ "size").extractOpt[String].getOrElse("N/A")
        // mountpoint can be null, so handle it gracefully
        val mountpoint = (device \ "mountpoint").extractOpt[String].getOrElse("N/A")
        println(f"  Device: $name%-10s Size: $size%-10s Mountpoint: $mountpoint")
      }
    } catch {
      case e: Exception => println(s"Could not retrieve disk information: ${e.getMessage}")
    }
  }

  def testDiskIo(): Unit = {
    val testDir = "/tmp/spark-io-test"
    s"mkdir -p $testDir".!

    println("\n--- Testing Disk Throughput (1G Sequential Write) ---")
    try {
      val throughputCmd = s"fio --name=throughput-test --directory=$testDir --size=1G --rw=write --bs=1M --direct=1 --numjobs=1 --group_reporting --output-format=json"
      val throughputResult = throughputCmd.!!
      val parsedThroughput = parse(throughputResult)
      
      val writeStats = (parsedThroughput \ "jobs")(0) \ "write"
      val throughput = (writeStats \ "bw").extract[Double]
      val unit = (writeStats \ "bw_bytes").extract[Long] match {
        case b if b >= 1024*1024 => f"${throughput/1024}%.2f MiB/s"
        case b if b >= 1024 => f"$throughput%.2f KiB/s"
        case _ => f"$throughput%.2f B/s"
      }
      println(s"Average Write Throughput: $unit")
    } catch {
      case e: Exception => println(s"Throughput test failed: ${e.getMessage}. Make sure 'fio' is installed (`sudo apt-get install fio` or `sudo yum install fio`).")
    }

    println("\n--- Testing Disk IOPS (1G Random Write) ---")
    try {
      val iopsCmd = s"fio --name=iops-test --directory=$testDir --size=1G --rw=randwrite --bs=4k --direct=1 --numjobs=1 --group_reporting --output-format=json"
      val iopsResult = iopsCmd.!!
      val parsedIops = parse(iopsResult)
      
      val writeStats = (parsedIops \ "jobs")(0) \ "write"
      val iops = (writeStats \ "iops").extract[Double]
      println(f"Average Write IOPS: $iops%.2f")

    } catch {
      case e: Exception => println(s"IOPS test failed: ${e.getMessage}. Make sure 'fio' is installed.")
    } finally {
      s"rm -rf $testDir".!
    }
  }

	def main(args: Array[String]): Unit = {
			if(args.length < 1){
				throw new Exception("absent parameters")
			}
		run(args(0))
	}
}
