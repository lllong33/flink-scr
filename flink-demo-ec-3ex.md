# 基于FlinkSQL实现Top10商品统计
阿里-伍翀（云邪）分享地址: http://wuchong.me/blog/2020/02/25/demo-building-real-time-application-with-flink-sql/#more


IS-1 本地配置代理, 解决docker pull 问题;

IS-2 碰到 flink 出现无法获取元数据; 
- 在一通添加各种配置无效后, hostname, ip等信息; 依旧无法解决; 
- 晚上重新拉取了一次 yml 文件, down + recreate 了下镜像解决


IS-3 flink 1.16 with 参数有更新
CREATE TABLE user_behavior (
    user_id BIGINT,
    item_id BIGINT,
    category_id BIGINT,
    behavior STRING,
    ts TIMESTAMP(3),
    proctime as PROCTIME(),   -- 通过计算列产生一个处理时间列
    WATERMARK FOR ts as ts - INTERVAL '5' SECOND  -- 在ts上定义watermark，ts成为事件时间列
) WITH (
    'connector' = 'kafka',  -- 使用 kafka connector
    'topic' = 'user_behavior',  -- kafka topic
    'scan.startup.mode' = 'earliest-offset',  -- 从起始 offset 开始读取
    'properties.bootstrap.servers' = 'localhost:9092',  -- kafka broker 地址
    'format' = 'json'  -- 数据源格式为 json
);



CREATE TABLE buy_cnt_per_hour ( 
    hour_of_day BIGINT,
    buy_cnt BIGINT
) WITH (
    'connector' = 'elasticsearch-7',
    'hosts' = 'http://localhost:9200',
    'index' = 'buy_cnt_per_hour',      -- elasticsearch 索引名，相当于数据库的表名
    'document-type' = 'user_behavior', -- elasticsearch 的 type，相当于数据库的库
    'max-actions' = '1', -- 每条数据都刷新
    'format' = 'json'   -- 输出数据格式 json
);

ES 定义了主键就是 upsert 模式, 否则即 append 模式;
这里不能查, 只能用于 sink

INSERT INTO but_cnt_per_hour
select HOUR(TUMBLE_START(ts, INTERVAL '1' HOUR)), count(*)
from user_behavior
where behavior = 'buy'
group by tumble(ts, interval '1' HOUR);


IS-4 select 看不到数据, UI一直显示create中
Connection to node -1 (localhost/127.0.0.1:9092) could not be established. Broker may not be available.
org.apache.kafka.common.errors.TimeoutException: Timed out waiting for a node assignment. Call: fetchMetadata
2023-01-14 16:06:39,551 ERROR org.apache.flink.runtime.source.coordinator.SourceCoordinatorContext [] - Exception while handling result from async call in SourceCoordinator-Source: user_behavior[7]. Triggering job failover.
org.apache.flink.util.FlinkRuntimeException: Failed to list subscribed topic partitions due to 
	at org.apache.flink.connector.kafka.source.enumerator.KafkaSourceEnumerator.checkPartitionChanges(KafkaSourceEnumerator.java:234) ~[flink-connector-kafka-1.16.0.jar:1.16.0]
	at org.apache.flink.runtime.source.coordinator.ExecutorNotifier.lambda$null$1(ExecutorNotifier.java:83) ~[flink-dist-1.16.0.jar:1.16.0]
	at org.apache.flink.util.ThrowableCatchingRunnable.run(ThrowableCatchingRunnable.java:40) [flink-dist-1.16.0.jar:1.16.0]
	at java.util.concurrent.Executors$RunnableAdapter.call(Executors.java:511) [?:1.8.0_144]
	at java.util.concurrent.FutureTask.run(FutureTask.java:266) [?:1.8.0_144]
	at java.util.concurrent.ScheduledThreadPoolExecutor$ScheduledFutureTask.access$201(ScheduledThreadPoolExecutor.java:180) [?:1.8.0_144]
	at java.util.concurrent.ScheduledThreadPoolExecutor$ScheduledFutureTask.run(ScheduledThreadPoolExecutor.java:293) [?:1.8.0_144]
	at java.util.concurrent.ThreadPoolExecutor.runWorker(ThreadPoolExecutor.java:1149) [?:1.8.0_144]
	at java.util.concurrent.ThreadPoolExecutor$Worker.run(ThreadPoolExecutor.java:624) [?:1.8.0_144]
	at java.lang.Thread.run(Thread.java:748) [?:1.8.0_144]
Caused by: java.lang.RuntimeException: Failed to get metadata for topics [user_behavior].
	at org.apache.flink.connector.kafka.source.enumerator.subscriber.KafkaSubscriberUtils.getTopicMetadata(KafkaSubscriberUtils.java:47) ~[flink-connector-kafka-1.16.0.jar:1.16.0]
	at org.apache.flink.connector.kafka.source.enumerator.subscriber.TopicListSubscriber.getSubscribedTopicPartitions(TopicListSubscriber.java:52) ~[flink-connector-kafka-1.16.0.jar:1.16.0]
	at org.apache.flink.connector.kafka.source.enumerator.KafkaSourceEnumerator.getSubscribedTopicPartitions(KafkaSourceEnumerator.java:219) ~[flink-connector-kafka-1.16.0.jar:1.16.0]
	at org.apache.flink.runtime.source.coordinator.ExecutorNotifier.lambda$notifyReadyAsync$2(ExecutorNotifier.java:80) ~[flink-dist-1.16.0.jar:1.16.0]
	... 7 more
看起来是docker 9092 连接不上
/opt/apps/kafka/bin/kafka-console-consumer.sh --bootstrap-server node1:9092 --topic user_behavior --from-beginning --max-messages 10
直接用本地client是可以消费; 

容器网络使用<container>:9092访问kafka，主机网络使用<host>:9094访问kafka。
IS-4.1 这里拆分两个端口原因?

CREATE TABLE user_behavior (
     user_id BIGINT,
     item_id BIGINT,
     category_id BIGINT,
     behavior STRING,
     ts TIMESTAMP(3),
     proctime as PROCTIME(),   -- 通过计算列产生一个处理时间列
     WATERMARK FOR ts as ts - INTERVAL '5' SECOND  -- 在ts上定义watermark，ts成为事件时间列
 ) WITH (
     'connector' = 'kafka',  -- 使用 kafka connector
     'topic' = 'user_behavior',  -- kafka topic
     'scan.startup.mode' = 'latest-offset', --'earliest-offset',  -- 从起始 offset 开始读取
     'properties.bootstrap.servers' = 'localhost:9092',  -- kafka broker 地址
     'format' = 'json'  -- 数据源格式为 json
 );

查看 kafka 没有日志
有点无法解决, 尝试使用 docker-flink




# docker-flink, docker-组件
https://github.com/aiven/sql-cli-for-apache-flink-docker
http://wuchong.me/blog/2020/02/25/demo-building-real-time-application-with-flink-sql/#more

合并两个docker_compose文件, 解决容器间网络不一致问题;

docker exec -it sql-client /opt/sql-client/sql-client.sh


- 问题1 kafka无法获取元数据, 是否配置不应该设置为localhost, 而是docker的ip地址?
Error while loading kafka-version.properties: inStream parameter is null
org.apache.flink.kafka.shaded.org.apache.kafka.common.errors.TimeoutException: Timed out waiting for a node assignment. Call: fetchMetadata
ERROR org.apache.flink.runtime.source.coordinator.SourceCoordinatorContext [] - Exception while handling result from async call in SourceCoordinator-Source: user_behavior[1]. Triggering job failover.
org.apache.flink.util.FlinkRuntimeException: Failed to list subscribed topic partitions due to 

- 问题2 ts字段格式要求?
Failed to deserialize JSON '{"user_id": "952483", "item_id":"310884", "category_id": "4580532", "behavior": "pv", "ts": "2017-11-27T00:00:00Z"}'.
Fail to deserialize at field: ts.
Text '2017-11-27T00:00:00Z' could not be parsed at index 10
Caused by: java.time.format.DateTimeParseException: Text '2017-11-27T00:00:00Z' could not be parsed at index 10
	at java.time.format.DateTimeFormatter.parseResolved0(Unknown Source) ~[?:?]
	at java.time.format.DateTimeFormatter.parse(Unknown Source) ~[?:?]
	at org.apache.flink.formats.json.JsonToRowDataConverters.convertToTimestamp(JsonToRowDataConverters.java:224) ~[flink-json-1.16.0.jar:1.16.0]
	at org.apache.flink.formats.json.JsonToRowDataConverters.lambda$wrapIntoNullableConverter$de0b9253$1(JsonToRowDataConverters.java:380) ~[flink-json-1.16.0.jar:1.16.0]
	at org.apache.flink.formats.json.JsonToRowDataConverters.convertField(JsonToRowDataConverters.java:370) ~[flink-json-1.16.0.jar:1.16.0]
	at org.apache.flink.formats.json.JsonToRowDataConverters.lambda$createRowConverter$ef66fe9a$1(JsonToRowDataConverters.java:350) ~[flink-json-1.16.0.jar:1.16.0]
	at org.apache.flink.formats.json.JsonToRowDataConverters.lambda$wrapIntoNullableConverter$de0b9253$1(JsonToRowDataConverters.java:380) ~[flink-json-1.16.0.jar:1.16.0]
	at org.apache.flink.formats.json.JsonRowDataDeserializationSchema.convertToRowData(JsonRowDataDeserializationSchema.java:131) ~[flink-json-1.16.0.jar:1.16.0]
	at org.apache.flink.formats.json.JsonRowDataDeserializationSchema.deserialize(JsonRowDataDeserializationSchema.java:116) ~[flink-json-1.16.0.jar:1.16.0]
	at org.apache.flink.formats.json.JsonRowDataDeserializationSchema.deserialize(JsonRowDataDeserializationSchema.java:51) ~[flink-json-1.16.0.jar:1.16.0]
	at org.apache.flink.api.common.serialization.DeserializationSchema.deserialize(DeserializationSchema.java:82) ~[flink-dist-1.16.0.jar:1.16.0]
	at org.apache.flink.streaming.connectors.kafka.table.DynamicKafkaDeserializationSchema.deserialize(DynamicKafkaDeserializationSchema.java:113) ~[?:?]
	at org.apache.flink.connector.kafka.source.reader.deserializer.KafkaDeserializationSchemaWrapper.deserialize(KafkaDeserializationSchemaWrapper.java:54) ~[?:?]
	at org.apache.flink.connector.kafka.source.reader.KafkaRecordEmitter.emitRecord(KafkaRecordEmitter.java:53) ~[?:?]
	... 14 more
TODO 尝试使用代码的尝试看下, 为什么解析报错来着; 暂时先看看文档有其他类型对应 2017-11-27T00:00:00Z
2017-11-27T00:00:00Z 即UTC日期格式    
UTC就是世界标准时间，与北京时间相差八个时区。所以只要将UTC时间转化成一定格式的时间，再在此基础上加上8个小时就得到北京时间了。
参考: https://www.cnblogs.com/zjdxr-up/p/9673050.html
将utc 格式时间转换为timestamp 时间戳 -> timestamp(3)
```sql
CREATE TABLE user_behavior (
    user_id BIGINT,
    item_id BIGINT,
    category_id BIGINT,
    behavior STRING,
    ts STRING,
    -- std_ts as to_timestamp(replace(replace(ts,'T',' '),'Z',''),'yyyy-MM-dd HH:mm:ss'),
    std_ts as to_timestamp_ltz(unix_timestamp(replace(replace('2017-11-27T00:00:00Z','T', ' '),'Z','')) * 1000,3),
    proctime as PROCTIME(),   -- 通过计算列产生一个处理时间列
    WATERMARK FOR std_ts as std_ts - INTERVAL '5' SECOND  -- 在ts上定义watermark，ts成为事件时间列
) WITH (
    'connector' = 'kafka',  -- 使用 kafka connector
    'topic' = 'user_behavior',  -- kafka topic
    'scan.startup.mode' = 'earliest-offset',  -- 从起始 offset 开始读取
    'properties.bootstrap.servers' = 'kafka:9092',  -- kafka broker 地址
    'format' = 'json'  -- 数据源格式为 json
);
-- utc -> unixtime
select unix_timestamp(replace(replace('2017-11-27T00:00:00Z','T',' '),'Z',''),'yyyy-MM-dd HH:mm:ss');

-- unixtime -> 1970-01-18 11:55:40.000
select TO_TIMESTAMP(FROM_UNIXTIME(1511740800 / 1000, 'yyyy-MM-dd HH:mm:ss'))

-- 转换不带时区 utc -> timestamp(3)
select to_timestamp(replace(replace('2017-11-27T00:00:00Z','T',' '),'Z',''),'yyyy-MM-dd HH:mm:ss') 

-- procetime 要求 timestamp_ltz(3) ? 
to_timestamp_ltz(unix_timestamp(replace(replace('2017-11-27T00:00:00Z','T', ' '),'Z','')) * 1000,3)

```


参考: https://blog.csdn.net/zhangdongan1991/article/details/105796613
flink 1.1 中watermark必须是列 timestamp(3)
UNIXTIME -> timestamp 13位的时间戳(1587975971431)
ts AS TO_TIMESTAMP(FROM_UNIXTIME(app_time / 1000, 'yyyy-MM-dd HH:mm:ss')), -- 定义事件时间


IS-4.2 尝试去掉ts字段, 用 stream api 读取, sql 都验证下
```sql
{"user_id":"980877","item_id":"5097906","category_id":"49192","behavior":"pv","ts":"2017-11-27T00:00:00Z"}
{"user_id":"980877","item_id":"5097906","category_id":"49192","behavior":"pv","ts":"2017-11-27 00:00:00"}


CREATE TABLE user_behavior (
    user_id BIGINT,
    item_id BIGINT,
    category_id BIGINT,
    behavior STRING,
    ts STRING,
    std_ts as to_timestamp_ltz(unix_timestamp(replace(replace('2017-11-27T00:00:00Z','T', ' '),'Z','')) * 1000,3),
    proctime as PROCTIME()   -- 通过计算列产生一个处理时间列
) WITH (
    'connector' = 'kafka',  -- 使用 kafka connector
    'topic' = 'user_behavior',  -- kafka topic
    'scan.startup.mode' = 'earliest-offset',  -- 从起始 offset 开始读取
    'properties.bootstrap.servers' = 'kafka:9092',  -- kafka broker 地址
    'format' = 'json'  -- 数据源格式为 json
);


-- 创建新topic, 不包含ts字段
./kafka-topics.sh --create --zookeeper zookeeper:2181 --topic user_behavior_v2 --partitions 1 --replication-factor 1
./kafka-topics.sh --list --zookeeper zookeeper:2181
./kafka-console-producer.sh --broker-list kafka:9092 --topic user_behavior_v2
{"user_id":"980877","item_id":"5097906","category_id":"49192","behavior":"pv"}



CREATE TABLE user_behavior_v2 (
    user_id BIGINT,
    item_id BIGINT,
    category_id BIGINT,
    behavior STRING
) WITH (
    'connector' = 'kafka',  -- 使用 kafka connector
    'topic' = 'user_behavior',  -- kafka topic
    'scan.startup.mode' = 'earliest-offset',  -- 从起始 offset 开始读取
    'properties.bootstrap.servers' = 'kafka:9092',  -- kafka broker 地址
    'format' = 'json'  -- 数据源格式为 json
);


```


- 尝试剔除ts字段, fs-kafka是否正常
  - 第二个问题没了, 第一个问题还存在, 依旧无法获取到数据
另外拿一个之前的用例参考 
    - flink-tutorial 
        IS-4.2 maven 自动设置为JDK1.5
    - atguigu 数仓
    - flink-cookbook 

- 确定proctime 字段类型格式
- event_time 字段类型格式, timestamp(3) ?
- 最好能看下源码, 限制的原因?


