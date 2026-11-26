name := "gcptest"
version := "0.1.0"

// Cross-build for Managed Spark Cluster 2.3 (Scala 2.12.18) and Serverless 2.3 (Scala 2.13.8)
val scala212 = "2.12.18"
val scala213 = "2.13.8"

scalaVersion := scala212
crossScalaVersions := Seq(scala212, scala213)

// Matches Spark 3.5.3 preinstalled on both Cluster 2.3 and Serverless 2.3
val sparkVersion = "3.5.3"

scalacOptions ++= (CrossVersion.partialVersion(scalaVersion.value) match {
  case Some((2, 12)) => Seq("-deprecation", "-target:jvm-1.8")
  case Some((2, 13)) => Seq("-deprecation", "-release", "11")
  case _             => Seq("-deprecation")
})

// Define Spark and GCS dependencies (platform-provided) plus shaded application deps
libraryDependencies ++= Seq(
  "org.apache.spark" %% "spark-core" % sparkVersion % "provided",
  "org.apache.spark" %% "spark-sql"  % sparkVersion % "provided",
  "org.json4s" %% "json4s-native" % "4.0.7",
  "com.google.cloud.bigdataoss" % "gcs-connector" % "3.1.13" % "provided"
)

// Do not bundle scala-library; the Managed Spark runtime provides it
assembly / assemblyPackageScala / assembleArtifact := false

// Include Scala binary version in fat JAR name so 2.12 (Cluster 2.3) and 2.13 (Serverless 2.3) coexist cleanly
assembly / assemblyJarName := s"${name.value}_${scalaBinaryVersion.value}-${version.value}-assembly.jar"

assembly / assemblyShadeRules := Seq(
  ShadeRule.rename("org.json4s.**" -> "bindiego.shaded.json4s.@1").inAll
)

assembly / assemblyMergeStrategy := {
  case PathList("META-INF", "services", _*) => MergeStrategy.concat
  case PathList("META-INF", _*)             => MergeStrategy.discard
  case "module-info.class"                  => MergeStrategy.discard
  case _                                    => MergeStrategy.first
}
