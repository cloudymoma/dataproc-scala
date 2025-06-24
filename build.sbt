name := "gcptest"
version := "0.1.0"
scalaVersion := "2.12.20" // Use a Scala version compatible with your Spark cluster

val sparkVersion = "3.5.6"

// Define Spark dependencies
libraryDependencies ++= Seq(
  "org.apache.spark" %% "spark-core" % sparkVersion % "provided",
  "org.apache.spark" %% "spark-sql"  % sparkVersion % "provided",
  "org.json4s" %% "json4s-native" % "4.0.7"
)

assembly / assemblyShadeRules := Seq(
  ShadeRule.rename("org.json4s.**" -> "bindiego.shaded.json4s.@1").inAll
)

assembly / assemblyMergeStrategy := {
  case PathList("META-INF", xs @ _*) => MergeStrategy.discard
  case x => MergeStrategy.first
}

