CREATE TABLE user_behavior(
    user_id BIGINT
    ,item_id BIGINT
    ,category_id BIGINT
    ,behavior STRING
    ,ts TIMESTAMP(3) 
    ,proctime as proctime()
    ,WATERMARK FOR ts as ts - INTERVAL '5' second
) with (    
    'connector' = 'filesystem',
    'connector.version' = 'universal',
    'connector.topic' = 'user_behavior',
    'connector.startup-mode' = 'latest-offset',
    'connector.properties.zookeeper.connect' = 'node1:2181',
    'connector.properties.bootstrap.servers' = 'node1:9092',
    'format.type' = 'json'
)

# shell 进入当前文件目录



-- 测试下 csv -> flink 
CREATE TABLE trades (
    AccountNo varchar(10),
    Symbol varchar(10),
    Quantity integer,
    BuySell varchar(4),
    Price decimal    
) WITH ( 
    'connector' = 'filesystem',
    'path' = 'file:///opt/apps/flink-playgrounds-git/top_10_behavior_3ex/c1.csv',
    'format' = 'csv'  
);

--IS-1 java.lang.ClassNotFoundException: org.apache.flink.table.factories.BulkWriterFormatFactory
google 搜索没有相同问题, 诡异 filesystem 不是内置的包吗? 
怀疑table包有问题, 

-- systemctl format-csv 与 filesystem-csv 区别
后者支持分区文件访问


CREATE TABLE trades (
    AccountNo varchar(10),
    Symbol varchar(10),
    Quantity integer,
    BuySell varchar(4),
    Price decimal    
) WITH ( 
    'connector' = 'filesystem',
    'path' = 'file:///opt/apps/flink-playgrounds-git/top_10_behavior_3ex/c1.csv',
    'format' = 'csv'  
);

docker-compose exec kafka bash -c 'kafka-console-consumer.sh --topic user_behavior --bootstrap-server kafka:9094 --from-beginning --max-messages 10'



IS-1
docker-compose mysql端口占用, 修改3307:3306, 需要重新 up -d 才会recreate


IS-2 
Configured end points localhost:9092 in advertised listeners are already registered by broker 1001
重启问题不在了

IS-3 
内部代码存在错误来着
creating topics: "user_behavior:1:1"
Missing required argument "[partitions]"

[2023-01-12 05:38:08,927] WARN [Consumer clientId=consumer-1, groupId=console-consumer-58376] Error while fetching metadata with correlation id 35 : {user_behavior=LEADER_NOT_AVAILABLE} (org.apache.kafka.clients.NetworkClient)

- KAFKA_ADVERTISED_LISTENERS=INSIDE://:9094,OUTSIDE://192.168.133.14:9092
- KAFKA_LISTENERS=INSIDE://:9094,OUTSIDE://:9092
这里配置要指定具体ip?


kafka-topics.sh --list --zookeeper zookeeper:2181
kafka-console-consumer.sh --topic user_behavior --bootstrap-server kafka:9094 --from-beginning --max-messages 10

# 创建一个test topics 测试下


看配置日志, 里面两个为null
advertised.host.name = null
advertised.listeners = INSIDE://:9094,OUTSIDE://:9092
advertised.port = null

KAFKA_ADVERTISED_HOST_NAME
KAFKA_ADVERTISED_PORT=9092



# 尝试使用本机 WSL2 安装docker, 拉取下镜像测试下
参考: https://blog.csdn.net/weixin_39786155/article/details/110363154
分为原生/window docker desktop 两种方式, 

unable to add return rule in DOCKER
参考: https://blog.csdn.net/0210/article/details/124349371
iptables-nft 问题

sudo update-alternatives --config iptables
改用 iptables-legacy

关于docker_compose
参考: https://www.digitalocean.com/community/tutorials/how-to-install-and-use-docker-compose-on-ubuntu-20-04




