---
title: Spring Boot 启动速度优化
date: 2018-06-19 17:34:46
tags: 
  - spring boot
  - java
categories: 笔记
---

# Spring Boot 启动速度优化

开始优化...

现用版本: java8; spring boot 1.5, gradle3.3; 监控工具: jProfiler9.2.1

> 参考文章: 
>
> [Spring Boot Performance --Alex Collins](https://alexecollins.com/spring-boot-performance/)
>
> [Configure a Spring Boot Web Application](http://www.baeldung.com/spring-boot-application-configuration)

## 组件自动扫描问题

### @SpringBootApplication 

默认情况下, 我们会使用`@SpringBootApplication`注解来自动获取应用的配置信息. 这样会有一些副作用. 其中一个就是组件扫描`@ComponentScan` . 它会拖慢应用启动的速度, 也会加载一些不必要的bean. 

### @EnableAutoConfiguration

所以第一步就是干掉这两个注解, 使用`EnableAutoConfiguration` 来代替. 然后需要手动`Import`需要的class.

~~~java
@EnableAutoConfiguration
@Configuration
@Import(value = {
  DefaultConfiguration.class,
  BeforeControllerAdvice.class,
  DefaultSearchServiceImpl.class,
  SearchController.class,
})
public class DemoApplication {
  public static void main(String[] args) {
    SpringApplication.run(DemoApplication.class, args);
  }
}
~~~

如果不知道需要引入哪些类, 可以通过在启动命令中加入`-Ddebug`来打印出那些类是自动加载的. 

> [Spring Boot Performance]((https://alexecollins.com/spring-boot-performance/))中提到的`DispatcherServletAutoConfiguration`等class, 不需要引入, 在项目启动时也会自动加载, 只需要`Import`自己写的类即可. 

##  修改Servlet

### Tomcat

默认情况下, Spring Boot使用Tomcat. Tomcat使用大约110MB的堆, 并且具有~16个线程.

### Undertow

Undertow是一个用java编写的灵活的高性能Web服务器, 提供基于NIO的阻塞和非阻塞API.

相比于tomcat, undertow会占用更少的内存.

### 如何将servlet改为undertow

~~~java
compile("org.springframework.boot:spring-boot-starter-web:${springBootVersion}")
    {
      exclude group: "org.springframework.boot", module: "spring-boot-starter-tomcat"
    }
  compile group: "org.springframework.boot", name: "spring-boot-starter-undertow", version: "${springBootVersion}"
~~~

若使用了`spring-boot-starter-tomcat`的其他工具类, 请自行引用相应工具类.

## -Xmx 

`-Xmx`参数是限制JVM的最大Heap, 若没有设置JVM会尽量多的吃更多的内存, 根据项目的实际需求设置`Xmx`可以避免java项目吃掉太多内存

## java10

最后, 也是最重要的一点, java10对java项目的启动做了优化, 将jdk版本升级到10以后, java的启动速度明显加快.

在java10, sping boot 2.0的环境下, 相比于java8, 快了20%以上(仅以一个项目做过测试, 数据仅供参考)

**由于升级所带来的一些困扰, 不同的项目自行解决...**