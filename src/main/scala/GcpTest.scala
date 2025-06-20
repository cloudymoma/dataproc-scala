import org.apache.spark.SparkConf
import org.apache.spark.sql.{SparkSession, SaveMode}
import org.apache.spark.sql.functions._
import org.apache.spark.util.LongAccumulator // Added for accumulators
import org.apache.spark.sql.execution.datasources.SQLHadoopMapReduceCommitProtocol // For metrics, though might not be directly used for custom listeners
import org.apache.spark.scheduler.{SparkListener, SparkListenerTaskEnd} // For listening to task events

object GcpTest {

	def run(Day: String): Unit ={
		val conf = new SparkConf().setAppName("GCS FileIO Test")
//		conf.set("spark.sql.hive.metastore.uris", "grpc://dataproc-metadata-hive-34c3cfdd-vdbq7vognq-uk.a.run.app:443")
//		conf.set("spark.sql.hive.metastore.rpc", "grpc")
//		conf.set("spark.sql.catalogImplementation", "hive")
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

		spark.stop()
	}

	def main(args: Array[String]): Unit = {
			if(args.length < 1){
				throw new Exception("absent parameters")
			}
		run(args(0))
	}
}
