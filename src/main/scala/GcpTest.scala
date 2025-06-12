import org.apache.spark.SparkConf
import org.apache.spark.sql.SparkSession
import org.apache.spark.sql.functions._

object GcpTest {

	def run(Day: String): Unit ={
		val conf = new SparkConf().setAppName("GrpcTest")
//		conf.set("spark.sql.hive.metastore.uris", "grpc://dataproc-metadata-hive-34c3cfdd-vdbq7vognq-uk.a.run.app:443")
//		conf.set("spark.sql.hive.metastore.rpc", "grpc")
//		conf.set("spark.sql.catalogImplementation", "hive")
		val spark = SparkSession.builder.config(conf).enableHiveSupport().getOrCreate()

        import spark.implicits._

        val fakeDataDF = spark.range(10) 
          .withColumn("uid", expr("uuid()")) 
          .withColumn("max_days", (rand() * 100 + 1).cast("int")) 
          .select("uid", "max_days") 

        println("Generated data using the DataFrame API:")
        fakeDataDF.show()
        fakeDataDF.printSchema()

		fakeDataDF.repartition(1).write.orc("gs://dingoproc/scala_output")

		spark.stop()
	}

	def main(args: Array[String]): Unit = {
			if(args.length < 1){
				throw new Exception("absent parameters")
			}
		run(args(0))
	}
}
