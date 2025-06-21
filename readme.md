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
