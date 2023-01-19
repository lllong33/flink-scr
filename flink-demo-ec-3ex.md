# 基于FlinkSQL实现Top10商品统计
阿里-伍翀（云邪）分享地址: http://wuchong.me/blog/2020/02/25/demo-building-real-time-application-with-flink-sql/#more


IS-1 本地配置代理, 解决docker pull 问题;(done)

IS-2 碰到 flink 出现无法获取元数据; (done)
- 在一通添加各种配置无效后, hostname, ip等信息; 依旧无法解决; 
- 晚上重新拉取了一次 yml 文件, down + recreate 了下镜像解决


IS-3 flink 1.16 with 参数有更新 (done)
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





IS-4 select 看不到数据, UI一直显示create中 (done)
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
IS-4.1 这里拆分两个端口原因?(done)

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


IS-5 kafka无法获取数据
已排查create table 语句问题
IS-5.1 待排查连接问题, 在IDEA, 集群, docker 三个环节中测试
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


IS-4.2 IDEA 尝试去掉ts字段, 用 stream api 读取, sql 都验证下(done)
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


-- 测试带ts的数据, normal
-- 使用UTC即原始ts作为WM, error-1, varchar - numeric 不支持
CREATE TABLE user_behavior (
    user_id BIGINT,
    item_id BIGINT,
    category_id BIGINT,
    behavior STRING,
    -- ts TIMESTAMP(3),
    -- proctime as PROCTIME(),   -- 通过计算列产生一个处理时间列
    -- WATERMARK FOR ts as ts - INTERVAL '5' SECOND  -- 在ts上定义watermark，ts成为事件时间列
    ts STRING,
    std_ts as to_timestamp_ltz(unix_timestamp(replace(replace('2017-11-27T00:00:00Z','T', ' '),'Z','')) * 1000,3),
    proctime as PROCTIME(),   -- 通过计算列产生一个处理时间列
    WATERMARK FOR std_ts as std_ts - INTERVAL '5' SECOND  -- 在ts上定义watermark，ts成为事件时间列
) WITH (
    'connector' = 'kafka',  -- 使用 kafka connector
    'topic' = 'click',  -- kafka topic
    'scan.startup.mode' = 'earliest-offset',  -- 从起始 offset 开始读取
    'properties.bootstrap.servers' = 'node1:9092',  -- kafka broker 地址
    'format' = 'json'  -- 数据源格式为 json
);

```

IS-4.2.1 ts字段有格式要求, UTC不行
{"user_id":"980877","item_id":"5097906","category_id":"49192","behavior":"pv","ts":"2017-11-27T00:00:00Z"}
- 尝试剔除ts字段, fs-kafka是否正常(ok)
另外拿一个之前的用例参考 
- 确定proctime 字段类型格式
- event_time 字段类型格式, timestamp(3) ?


IS-4.3 为什么 FS 读到之前数据, 配置写错了?
metric日志都看不到了
先尝试验证环境的正确性, 使用flink-CK案例跑一下
- errror start-cluster.sh 卡在 JobMaster -> AppInfoParser -> ExecutionGraph ->  NettyTransport -> akka.remote.ReliableDeliverySupervisor 位置
- normal 单独起job和task任务, 执行flink sql 可以正常读取
- normal yarn-session.sh 方式也正常


IS-4.2 maven 自动设置为JDK1.5(done)
修改maven setting 文件, 设置默认值1.8




-- 检测kafka数据正常生成
docker-compose exec kafka bash -c 'kafka-console-consumer.sh --topic user_behavior --bootstrap-server kafka:9094 --from-beginning --max-messages 10'


docker install flink

https://github.com/aiven/sql-cli-for-apache-flink-docker.git

进入sql-client
docker exec -it sql-client /opt/sql-client/sql-client.sh


IS-1 docker pull 很慢, ubuntu 已配置代理, 需要代理验证方式
1.测试代理连通
2.测试代理速度

curl -L xxx 
-L 自动挑战到新地址


IS-2 kafka with 配置更新
IS-2.1 docker 镜像间如何访问

IS-2.1.1 两个docker-compose 起来的服务不在一个网段172.20, 172.23
暂时容器都写入一个docker-compose.yml文件中

IS-3 FS 无法消费到数据, 但是kafka-console-consumer.sh 可以消费到数据
```sql
./kafka-topics.sh --create --zookeeper zookeeper:2181 --topic click --partitions 1 --replication-factor 1
./kafka-topics.sh --list --zookeeper zookeeper:2181
./kafka-console-producer.sh --broker-list kafka:9092 --topic click
{"user_id":"980877","item_id":"5097906","category_id":"49192","behavior":"pv","ts":"2017-11-27T00:00:00Z"}

CREATE TABLE user_behavior (
    user_id BIGINT,
    item_id BIGINT,
    category_id BIGINT,
    behavior STRING,
    -- ts TIMESTAMP(3),
    -- proctime as PROCTIME(),   -- 通过计算列产生一个处理时间列
    -- WATERMARK FOR ts as ts - INTERVAL '5' SECOND  -- 在ts上定义watermark，ts成为事件时间列
    ts STRING,
    std_ts as to_timestamp_ltz(unix_timestamp(replace(replace('2017-11-27T00:00:00Z','T', ' '),'Z','')) * 1000,3),
    proctime as PROCTIME(),   -- 通过计算列产生一个处理时间列
    WATERMARK FOR std_ts as std_ts - INTERVAL '5' SECOND  -- 在ts上定义watermark，ts成为事件时间列
) WITH (
    'connector' = 'kafka',  -- 使用 kafka connector
    'topic' = 'user_behavior',  -- kafka topic
    'scan.startup.mode' = 'earliest-offset',  -- 从起始 offset 开始读取
    'properties.bootstrap.servers' = 'kafka:9094',  -- kafka broker 地址
    'format' = 'json'  -- 数据源格式为 json
);
```

Metadata update failed
Error while loading kafka-version.properties: inStream parameter is null
Kafka version: unknown
Kafka commitId: unknown
Kafka startTimeMs: 1673581220089


org.apache.flink.runtime.entrypoint.ClusterEntrypoint
GlobalConfiguration
AkkaRpcServiceUtils
DispatcherRestEndpoint
AkkaRpcService
JobMaster
StandaloneResourceManager
ExecutionGraph
org.apache.flink.kafka.shaded.org.apache.kafka.clients.ClientUtils [] - Couldn't resolve server node1:9092 from bootstrap.servers as DNS resolution failed for node1
error: Failed to create new KafkaAdminClient

很诡异, 配置sql_client镜像的dns, 依旧出现这个问题
- task/job 也配置看看, 问题解决

IS-4 出现新的异常, 确定为网络连接异常, flink -> kafka 获取broker列表失败(done)
Exception while handling result from async call in SourceCoordinator-Source: user_behavior[1]. Triggering job failover.
org.apache.flink.util.FlinkRuntimeException: Failed to list subscribed topic partitions due to 
TimeoutException: Timed out waiting for a node assignment. Call: describeTopics
TimeoutException: The AdminClient thread has exited. Call: fetchMetadata
Error while loading kafka-version.properties: inStream parameter is null

参考: https://help.aliyun.com/document_detail/177144.html
{"listener_security_protocol_map":{"INSIDE":"PLAINTEXT","OUTSIDE":"PLAINTEXT"},"endpoints":["INSIDE://8e01bd4ee16c:9094","OUTSIDE://localhost:9092"],"jmx_port":-1,"host":"8e01bd4ee16c","timestamp":"1673918486526","port":9094,"version":4}
能telnet通9092, 9094, 参考文章, 即使bootstrap.servers地址连通, 但endpoints中地址无法连通, 依旧无法读取/写入
参考之前9092-out, 测试下out端口
- endpoints显示imagId:9094, 但flink访问是hostname:9094, 无法访问, 是否docker无法路由导致?
- 尝试修改dockerfile, 改用ip:9092; 这个想法是错误的, 服务启动在镜像内, 不应该指向外部ip
- outsize这里为什么要设置localhost, 省略不行嘛? 与上面一样 error fetch metadata correlation
    - 参考SOF回答, 设置kafka, 容器内可访问(可解析dns), 设置localhosts, 容器外可访问(注意这里 localhost 指的容器ip, 不是宿主机ip), 不可兼得; 所有拆分了inside/outside两个端口;
    - 如果以上面为准, 设置localhost:9092, 外部访问应该正常; 
        - 但是出现 kafka client consumer 访问正常; 本地java服务访问失败;
参考: https://stackoverflow.com/questions/53586130/kafka-topic-creation-timed-out-waiting-for-a-node-assignment
确定docker-kafka存在多个版本, 很容易出现网络问题
[kafka client/server 网络连接详解](https://www.confluent.io/blog/kafka-client-cannot-connect-to-broker-on-aws-on-docker-etc/?spm=a2c4g.11186623.0.0.7155495dfarsnb)
- 暂时不用看, 作为以后深入资料

2023-01-19:
A1:
- 改用kafka:9094, 镜像中执行SQL可以正常运行了;

IS-4.1 outside 外部client访问失败, 访问服务器node1(192.168.133.14)中kafka:9092无法访问, 
- Timed out waiting for a node assignment
- [listenners详解](https://rmoff.net/2018/08/02/kafka-listeners-explained/)有点费劲, 找个java demo 测试下


## 统计每小时成交量
```sql
CREATE TABLE user_behavior (
    user_id BIGINT,
    item_id BIGINT,
    category_id BIGINT,
    behavior STRING,
    -- ts TIMESTAMP(3),
    -- proctime as PROCTIME(),   -- 通过计算列产生一个处理时间列
    -- WATERMARK FOR ts as ts - INTERVAL '5' SECOND  -- 在ts上定义watermark，ts成为事件时间列
    ts STRING,
    std_ts as to_timestamp_ltz(unix_timestamp(replace(replace(ts,'T', ' '),'Z','')) * 1000,3),
    proctime as PROCTIME(),   -- 通过计算列产生一个处理时间列
    WATERMARK FOR std_ts as std_ts - INTERVAL '5' SECOND  -- 在ts上定义watermark，ts成为事件时间列
) WITH (
    'connector' = 'kafka',  -- 使用 kafka connector
    'topic' = 'user_behavior',  -- kafka topic
    'scan.startup.mode' = 'earliest-offset',  -- 从起始 offset 开始读取
    'properties.bootstrap.servers' = 'kafka:9094',  -- kafka broker 地址
    'format' = 'json'  -- 数据源格式为 json
);
-- TODO 怎么替换掉ts字段? 使后续依旧使用ts作为水位线字段;

CREATE TABLE buy_cnt_per_hour ( 
    hour_of_day BIGINT,
    buy_cnt BIGINT
) WITH (
    'connector' = 'elasticsearch-7',
    'hosts' = 'http://elasticsearch:9200',
    'index' = 'buy_cnt_per_hour',      -- elasticsearch 索引名，相当于数据库的表名
    'document-type' = 'user_behavior', -- elasticsearch 的 type，相当于数据库的库
    'max-actions' = '1', -- 每条数据都刷新
    'format' = 'json'   -- 输出数据格式 json
);

ES 定义了主键就是 upsert 模式, 否则即 append 模式;
这里不能查, 只能用于 sink

INSERT INTO buy_cnt_per_hour
SELECT HOUR(TUMBLE_START(std_ts, INTERVAL '1' HOUR)), COUNT(*)
FROM user_behavior
WHERE behavior = 'buy'
GROUP BY TUMBLE(std_ts, INTERVAL '1' HOUR);

```
如何将本地lib包, 映射到docker中? 
- m1 通过 run wget -P xxx lib_addr
先映射到临时位置, 再运行cp命令?
- 为什么不能直接映射到lib目录下? 会出现权限问题?
- 会覆盖掉容器中原来文件;
```yml
volumes:
  - /usr/local/lib/python3.7/site-packages/pyflink/lib:/opt/flink/lib-custom
command: cp -a /opt/flink/lib-custom/. /opt/flink/lib/ && jobmanager
```

所有必需的依赖项（例如连接器）都需要在集群和客户端中可用




# tips
可参考的代码:
- flink-tutorial ()
- atguigu 数仓
- flink-cookbook 
flink config:
-- 跑flink-demo时配置, 利用多核
taskmanager.numberOfTaskSlots: 8
-- 手动调大资源
taskmanager.memory.process.size: 2096m


sql -> tableApi -> StreamApi
直接看 calcite 代码, 了解sql解析过程, 门槛较高, 暂时不适合


-- 停服务


# 总结
1. 对flink stream api , table api , flink sql 底层访问 kafka 机制不熟悉
- xml 配置, api
- with 参数

待提升, 关注点
tobManager 日志
metric 指标, 数据流程


不会看 java 日志, stack栈的信息未利用; 



