---
title: phpMyAdmin
date: 2018-06-11 11:00:20
tags: 
  - docker
  - mysql
categories: 笔记
---

# docker部署mysql&phpMyAdmin

记录如何使用docker部署mysql, 并通过myadmin管理, 不需要使用其他mysql工具

## 部署mysql

```yaml
mysql:
  image: mysql:5.6.40
  restart: always
  environment:
  - MYSQL_ROOT_PASSWORD=xxxxxxxx
  volumes:
  - /srv/mysql:/var/lib/mysql
  ports:
  - 3306:3306
```

这里需要指定mysql的密码, 并将`/var/lib/mysql`映射到主机上.

将3306端口映射到主机上, 以供其他服务连接.

## 部署phpmyadmin

```yaml
version: '2'
services:
  mysql:
    image: mysql:5.6.40
    restart: always
    environment:
    - MYSQL_ROOT_PASSWORD=xxxxxxxx
    volumes:
    - /srv/mysql:/var/lib/mysql
    ports:
    - 3306:3306
  phpmyadmin:
    image: phpmyadmin/phpmyadmin:4.8.1
    restart: always
    ports:
    - 33061:80
    volumes:
    - /srv/session:/session
    environment:
    - PMA_HOST=mysql
    - PMA_USER=root
    - PMA_PASSWORD=xxxxxxxx

```

对于phpMyAdmin的详细信息可以查看[https://github.com/phpmyadmin/docker](https://github.com/phpmyadmin/docker), 如配置用户账号密码.

我是直接使用nginx的访问控制.

然后配置nginx就可以访问phpMyAdmin的页面, 对数据库进行操作.

## 连接数据库

需要连接数据库是就可以用`内网ip:3306`来连接数据库. 如:

```java
SPRING_DATASOURCE_URL=jdbc:mysql://188.88.88.88:3306/database?characterEncoding=UTF-8&useUnicode=true&useJDBCCompliantTimezoneShift=true&useLegacyDatetimeCode=false&serverTimezone=Asia/Shanghai&zeroDateTimeBehavior=convertToNull&useSSL=false
```

