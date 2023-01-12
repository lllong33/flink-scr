
# 本地 ubuntu docker server 验证


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
CREATE TABLE user_behavior(
    user_id BIGINT
    ,item_id BIGINT
    ,category_id BIGINT
    ,behavior STRING
    ,ts TIMESTAMP(3) 
    ,proctime as proctime()
    ,WATERMARK FOR ts as ts - INTERVAL '5' second
) WITH (
  'connector' = 'kafka',
  'topic' = 'user_behavior',
  'properties.bootstrap.servers' = 'kafka:9092',
  'scan.startup.mode' = 'earliest-offset',
  'format' = 'json'
);

-- 错误的配置
) with (    
    'connector.type' = 'kafka',
    'connector.version' = 'universal',
    'connector.topic' = 'user_behavior',
    'connector.startup-mode' = 'latest-offset',
    'connector.properties.zookeeper.connect' = 'kafka:2181',
    'connector.properties.bootstrap.servers' = 'kafka:9092',
    'format.type' = 'json'
)
;

IS-2.1.1 两个docker-compose 起来的服务不在一个网段172.20, 172.23
暂时容器都写入一个docker-compose.yml文件中

IS-3 FS 无法消费到数据, 但是kafka-console-consumer.sh 可以消费到数据
Metadata update failed
Error while loading kafka-version.properties: inStream parameter is null
Kafka version: unknown
Kafka commitId: unknown
Kafka startTimeMs: 1673581220089



