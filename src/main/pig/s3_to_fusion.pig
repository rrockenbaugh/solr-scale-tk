REGISTER '$SSTK_JAR'
-- -p SSTK_JAR=s3://sstk-dev/solr-scale-tk-0.1-exe.jar -p REDUCERS=6 -p INPUT=s3://solr-scale-tk/pig/output/syn_sample_5m -p FUSION_BATCH_SIZE=500 -p FUSION_AUTH_ENABLED=true -p FUSION_USER=admin -p FUSION_PASS=password123 -p FUSION_REALM=native -p FUSION_ENDPOINT=http://ec2-52-91-12-62.compute-1.amazonaws.com:8764/api/apollo/index-pipelines/perf-default/collections/perf/index

SET mapred.map.tasks.speculative.execution false;
SET mapred.reduce.tasks.speculative.execution false;
SET mapred.child.java.opts -Xmx1g;

SET mapred.task.timeout 12000000;
SET mapred.max.tracker.failures 20;
SET mapred.map.max.attempts 20;

data = load '$INPUT' using PigStorage() as (id: chararray,
  integer1_i: int,
  integer2_i: int,
  long1_l: long,
  long2_l: long,
  float1_f: float,
  float2_f: float,
  double1_d: double,
  double2_d: double,
  timestamp1_tdt: chararray,
  timestamp2_tdt: chararray,
  string1_s: chararray,
  string2_s: chararray,
  string3_s: chararray,
  boolean1_b: chararray,
  boolean2_b: chararray,
  text1_en: chararray,
  text2_en: chararray,
  text3_en: chararray,
  random_bucket: float);

to_sort = foreach data generate id,
  integer1_i,
  integer2_i,
  long1_l,
  long2_l,
  float1_f,
  float2_f,
  double1_d,
  double2_d,
  timestamp1_tdt,
  timestamp2_tdt,
  string1_s,
  string2_s,
  boolean1_b,
  text1_en,
  text3_en;

to_solr = order to_sort by timestamp1_tdt ASC parallel $REDUCERS;
store to_solr into 'Fusion' using
  com.lucidworks.pig.FusionIndexPipelineStoreFunc('$FUSION_ENDPOINT','$FUSION_BATCH_SIZE','$FUSION_AUTH_ENABLED','$FUSION_USER','$FUSION_PASS','$FUSION_REALM','application/json');
