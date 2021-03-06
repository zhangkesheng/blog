---
title: Mysql-从优化到删库
date: 2020-04-17 14:50
tags:
	- mysql
	- level0
categories: 笔记
---

# Mysql-从优化到删库

作为一个鶸程序员, 遇到超过10行的SQL就会头疼不已, 更何况还是一个执行时长超过两年半的SQL. 所以想着怎么让他更小, 更快, 更强.

> 参考文章:
>
> 1. [MySQL 8.0.16 调优指南（鲲鹏920）](https://bbs.huaweicloud.com/forum/thread-25203-1-1.html)
> 2. [mysql优化的核心参数](https://blog.csdn.net/qq_39570637/article/details/81414300)
> 3. [数据库内核月报](http://mysql.taobao.org/monthly/)
> 4. [阿里巴巴Java开发手册](https://github.com/alibaba/p3c) 关于数据库的部分



首先, 可以优化的地方很多, 硬件, 系统配置, 数据库表结构, SQL语句.

从优化成本及优化效果上来说:

成本: 硬件> 系统配置> 数据库表结构> SQL语句/索引

效果: 硬件< 系统配置< 数据库表结构< SQL语句/索引

硬件方面也不用多说, 有钱哈哈哈, 没钱呵呵哒, 当然我们属于呵呵哒的, 就跳过了.

## 系统

系统参数方面主要介绍各个参数的意义, 作用及一些建议值. 因为并没有真正的去改动过这些参数, 所以只作为参考.

因为调整系统参数的影响并不只是影响某一个SQL, 而是会影响整个数据库或者服务器, 所以动手需谨慎.

而且每次修改只能修改一个参数, 然后确定性能变化, 来确定参数对性能的影响. 同时调整多个参数就无法确定真正影响性能的参数

### 系统参数

#### 网络参数

| 参数名称                | 参数含义                                                     | 建议                                                         |
| ----------------------- | ------------------------------------------------------------ | ------------------------------------------------------------ |
| tcp_max_syn_backlog     | tcp_max_syn_backlog 是指定所能接受SYN同步包的最大客户端数量. | 默认值是2048.<br />建议修改成8192.                           |
| net.core.somaxconn      | 服务端所能 accept 即处理数据的最大客户端数量, 即完成连接上限. | 默认值是128.<br />建议修改成1024.                            |
| net.core.rmem_max       | 接收套接字缓冲区大小的最大值.                                | 默认值是229376.<br />建议修改成16777216.                     |
| net.core.wmem_max       | 发送套接字缓冲区大小的最大值（以字节为单位）.                | 默认值是229376.<br />建议修改成16777216.                     |
| net.ipv4.tcp_rmem       | 配置读缓冲的大小, 三个值, 第一个是这个读缓冲的最小值, 第三个是最大值, 中间的是默认值. | 默认值是"4096 87380 6291456".<br />建议修改成"4096 87380 16777216". |
| net.ipv4.tcp_wmem       | 配置写缓冲的大小, 三个值, 第一个是这个读缓冲的最小值, 第三个是最大值, 中间的是默认值. | 默认值是"4096 16384 4194304".<br />建议修改成"4096 65536 16777216". |
| net.ipv4.max_tw_buckets | 表示系统同时保持 TIME_WAIT 套接字的最大数量.                 | 默认值是2048.<br />建议修改成360000.                         |

#### IO参数

| 参数名称                               | 参数含义                                              |
| -------------------------------------- | ----------------------------------------------------- |
| /sys/block/${device}/queue/scheduler   | 配置IO调度, deadline或者noop更适用于mysql数据库场景.  |
| /sys/block/${device}/queue/nr_requests | 提升磁盘吞吐量, 尤其对myisam存储引擎, 可以调整到更大. |

#### 缓存参数

| 参数名称    | 参数含义                                            |
| ----------- | --------------------------------------------------- |
| swappiness  | 值越大, 越积极使用swap分区, 值越小, 越积极使用内存. |
| dirty_ratio | 内存里的脏数据百分比不能超过这个值.                 |

### 数据库参数

#### CPU参数

| 参数名称                  | 参数含义                                                     | 建议                   |
| ------------------------- | ------------------------------------------------------------ | ---------------------- |
| innodb_thread_concurrency | 并发执行的线程的数量（同时干活的线程的数量）, 保护系统不被hang住 | 一般要求是cpu核数的4倍 |

#### 内存参数

| 参数名称                       | 参数含义                                                     | 建议                                                         |
| ------------------------------ | ------------------------------------------------------------ | ------------------------------------------------------------ |
| innodb_buffer_pool_size        | 缓存innodb表和索引数据的内存池大小                           | 通常建议内存的70%左右.<br />如果总是产生Innodb_buffer_pool_wait_free, 说明buffer_pool设置过小 |
| tmpdir                         | 存放临时文件和临时表目录, 可以设置多个路径用: 分隔           | 单独挂载, 对读写要求很高, 放在高性能盘, 独立分区             |
| innodb_buffer_pool_instances   | 开启多个内存缓冲池, 把需要缓冲的数据hash到不同的缓冲池中, 这样可以并行的内存读写 | 8个或者16个, 根据实际buffer pool大小设置, 如果实例数量过小, 会导致latch争用 |
| innodb_max_dirty_pages_pct     | buffer pool中最大脏页占比                                    | 75%~90%, 如果io能力足够强, 例如使用了闪卡, 可以将这个参数调小；该参数设置越小, 写入压力越大 |
| innodb_max_dirty_pages_pct_lwm | 预刷新脏页比例, 可以有效控制脏页比例达到最大脏页占比         | 70, 控制脏页比率, 防止达到脏页最大占比                       |

#### IO参数

| 参数名称                  | 参数含义                                                     | 建议                                                         |
| ------------------------- | ------------------------------------------------------------ | ------------------------------------------------------------ |
| innodb_io_capacity        | 设定了后台任务执行的io量的上限, 每秒后台进程处理IO数据的上限 | 一般为IO QPS总能力的75%                                      |
| innodb_io_capacity_max    | innodbio容量上限的最大值, 2000是初始默认值                   | 根据innodb_io_capacity的2倍进行设置                          |
| innodb_log_files_in_group | redo日志的组数, 即logfile的数量                              | 一般设置5组                                                  |
| innodb_log_file_size      | 每个logfile的大小                                            | 如果存在大量写操作, 建议增加日志文件大小, 但日志文件过大, 硬性数据恢复时间, 非生产环境, 测试极限性能尽量调大, 商用场景需要考虑数据恢复时间 |
| innodb_flush_method       | Log和数据刷新磁盘的方法: <br />\1.      datasync模式: 写数据时, write这一步并不需要真正写到磁盘才算完成（可能写入到操作系统buffer中就会返回完成）, 真正完成是flush操作, buffer交给操作系统去flush,并且文件的元数据信息也都需要更新到磁盘.<br />\2.      O_DSYNC模式: 写日志操作是在write这步完成, 而数据文件的写入是在flush这步通过fsync完成. | 建议O_DIRECT模式                                             |
| innodb_flush_neighbors    | 是否关闭邻接页刷新                                           | 一般关闭邻接页刷新                                           |

#### 连接参数

| 参数名称             | 参数含义                                                     | 建议                                                         |
| -------------------- | ------------------------------------------------------------ | ------------------------------------------------------------ |
| max_connections      | 允许客户端并发连接数量                                       | 1024, 一般不要超过2000                                       |
| max_user_connections | 任何一个mysql用户允许最大并发连接数                          | 256                                                          |
| table_open_cache     | 打开表缓存, 跟表数量没关系1000个连接上来, 都需要访问A表, 那么会打开1000个表, 打开1000个表是指mysql创建1000个这个表的对象, 连接直接访问表对象 | 4096 , 监控opened_tables值, 如果很大, 说明该值设置小了       |
| thread_cache_size    | Thread_Cache 中存放的最大连接线程数                          | 和物理内存有一定关系:<br />1G —> 8<br/>2G —> 16<br/>3G —> 32<br/>>3G —> 64 |
| wait_timeout         | 非交互连接（就是指那些连接池方式、非客户端方式连接的）的超时时间, 默认是28800, 就是8小时 | -                                                            |



## SQL语句

在进行MySQL优化前, 首先需要了解MySQL的查询过程. 只有了解了过程, 才知道依据什么去优化SQL.

![img](https://user-gold-cdn.xitu.io/2019/1/28/1689380186c7d6e7?imageView2/0/w/1280/h/960/ignore-error/1)

1. 客户端发送一条查询给服务器

2. 服务器先检查查询缓存, 如果命中了缓存, 则立刻返回存储在缓存中的结果否则进入下一阶段

3. 服务器端进行SQL解析、预处理, 再由优化器生成对应的执行计划

4. MySQL根据优化器生成的执行计划, 再调用存储引擎的API来执行查询

5. 将结果返回给客户端

### EXPLAIN

先要优化SQL之前, 我们得先知道从哪方面开rows始着手, `explain`就是Mysql自带的查询优化器, 负责Select语句的优化器模块, 可以模拟优化器执行SQL语句. 从而知道如何去优化SQL, 执行`Explain {{SQL}}`即可.

然后通过`explain`查询出来的属性, 判断如何优化.

1. table

   显示这一步所访问数据库中表名称（显示这一行的数据是关于哪张表的），有时不是真实的表名字，可能是简称，例如上面的e，d，也可能是第几步执行的结果的简称.

2. type

   反映sql优化的状态，至少达到range级别，最好能达到ref

   查询效率：system > const > eq_ref > ref > range > index > all

   1. all, 遍历全表
   2. index, 遍历索引树
   3. range, 范围检索, 使用一个索引来选择行
   4. ref, 非唯一性索引扫描, 返回匹配某个单独值的所有行
   5. eq_ref, 唯一索引扫描, 只匹配一条记录
   6. const, 当MySQL对查询某部分进行优化，并转换为一个常量时，使用这些类型访问。如将主键置于where列表中，MySQL就能将该查询转换为一个常量
   7. system, ystem是const类型的特例，查询的表只有一行

3. possible_keys

   MySQL可能使用的索引, 但实际查询中并不一定会使用

4. key

   MySQL实际使用的索引

5. ref

   哪些列或者常量被用来查询索引列上的值

6. rows

   估算的找到所需记录所需要读取的行数

7. extra

   包含MySQL解决查询的详细信息

   1. Using where, 使用了where条件过滤数据

   2. Using temporary, 使用临时表来存储结果集, 常见于排序和分组查询

   3. Using filesort, 无法利用索引完成的排序

   4. Using join buffer

      强调获取连接时没有使用索引, 并且需要使用连接缓冲区来存储中间结果.

      如果出现了这个值, 应该根据查询的实际情况添加索引来改进性能

   5. Impossible where, Where条件会导致没有符合的行, 即没有结果返回

   6. Using index codition, 会先过滤索引, 然后再从索引行中过滤

   7. No table userd, 查询中没有使用真实的表, 即没有From, 或者From dual

> **TIPS:**
>
> 1. explain`不会告诉你关于触发器, 存储过程及自定义函数对查询的影响
> 2. `explain`不考虑Cache
> 3. `explain` 不显示MySQL在执行查询时所作的优化工作
> 4. `explain`统计信息是估算的, 不是精确值
> 5. `explain`只能解释`select`语句

### 索引

索引问题是SQL问题中出现频率最高的, 常见的索引问题包括: 无索引和隐式转换. 

无索引会导致全表扫描, 如果表的数据量很大, 扫描大量数据.

隐式转换是指SQL查询中, 传入的条件值与对应字段的定义不一致导致索引无法使用. 

#### 索引的优缺点

**优点**

1. 大大的加快查询速度

**缺点**

1. 创建和维护索引需要耗费时间
2. 索引需要占用空间

#### 使用

1. 能不用索引就不要使用索引
2. 对于经常更新和插入的表避免进行过多的索引
3. 索引应该建在识别度高的字段上

#### 索引的类别

1. PRIMARY KEY: 主键索引, 值唯一且不能为NULL
2. UNIQUE: 唯一索引, 值唯一
3. INDEX: 普通索引, 值可以出现多次
4. FULLTEXT: 全文索引, 只有MyISAM上才能使用

#### 最左匹配原则

即最左优先, 以最左边为起点任何连续的索引都可以匹配上. 但遇到范围查询(>, <, between, like)时会停止匹配.

SQL中WHERE子句中条件的顺序并不会影响索引匹配, 因为有查询优化器, 会优化查询顺序.

例如: 

有(a, b, c)三个索引, 以下查询会全部都走索引

```sql
SELECT * FROM table_test WHERE a=1 AND b=2 AND c=3;
SELECT * FROM table_test WHERE c=1 AND b=2 AND a=3;
SELECT * FROM table_test WHERE b=1 AND c=2 AND a=3;
```

但是当最左侧的字段没有在WHERE子句中时, 则无法触发索引. 如下语句则不走索引:

```sql
SELECT * FROM table_test WHERE b=2 AND c=3;
```

#### 查询建议

1. 不要Select *, 只查询需要的字段
2. 尽量不使用like, 就算使用也要尽量避免使用'%xxx'. 左like不走索引. 如果必须可以考虑搜索引擎
3. Join表不要超过3个, 且join的字段类型必须一致, 字段不一致会有类型转换的消耗
4. Explain至少达到range级别
5. 精简查询语句

TO BE CONTINUE