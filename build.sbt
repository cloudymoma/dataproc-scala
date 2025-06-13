name := "gcptest"
version := "0.1.0"
scalaVersion := "2.13.16" // Use a Scala version compatible with your Spark cluster

val sparkVersion = "3.5.6"

// Define Spark dependencies
libraryDependencies ++= Seq(
  "org.apache.spark" %% "spark-core" % sparkVersion % "provided",
  "org.apache.spark" %% "spark-sql"  % sparkVersion % "provided"
)
