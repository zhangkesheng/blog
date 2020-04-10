---
title: 爬虫
date: 2020-04-10 11:19:26
tags:
	- crawler
	- Level0
categories: 笔记
---

# 爬虫

> 参考资料:
>
> 1. https://www.jianshu.com/p/189eed6a14fd
> 2. [https://baike.baidu.com/item/%E7%BD%91%E7%BB%9C%E7%88%AC%E8%99%AB](https://baike.baidu.com/item/网络爬虫)
> 3. https://segmentfault.com/a/1190000005840672
> 4. [Chrome无头浏览器-selenium3.0](https://www.jianshu.com/p/f410f1e7b38d)

## 什么是爬虫

爬虫, 也叫网络蜘蛛. 简单来说, 爬虫就是一段程序. 它根据既定的规则**批量**的获取互联网上的一些信息. 它可以不止疲倦的抓取网页上的信息, 省去了自己复制粘贴的工作.

## 你喜欢的爬虫, 你不喜欢的爬虫

互联网上的爬虫基本上都是令人讨厌的, 因为它会增加服务器负担, 并且盗用你的数据.

只有一类爬虫是人们喜爱的, 那就是各大搜索引擎爬虫. 只有被搜索引擎的爬虫爬取过的页面, 才能在搜索结果中展示.

## 爬虫的实现

### 基本构成

1. 待爬取的Url列表
2. Http Client: 用户下载Url内容
3. 解析器: 用于解析得到所需要的信息, 如HTML解析, Json解析
4. 存储: 保存爬取的结果. mysql, csv...

### 附加功能

1. 爬取列表更新策略
2. 爬取页面去重([布隆过滤器](https://www.jianshu.com/p/3e9282ca7080))
3. 多线程, 增加效率
4. 爬虫数据服务

### 流程

![1586337318650](C:\Users\User\AppData\Roaming\Typora\typora-user-images\1586337318650.png)

1. 拿到需要爬取的URL
2. 判断URL是否已下载. 若无, 则下载指定URL的内容
3. 提取结果中的URL添加至列表
4. 提取需要的数据
5. 保存数据

## 反爬虫

爬虫是通过一定的手段获取网站信息, 那反爬虫就是使用任何技术手段, 阻止别人批量获取自己网站信息的一种方式.

既然知道了爬虫的存在, 当然就要避免我们自己的服务被恶性爬虫爬取. 

### 为什么需要反爬虫

1. 保护自身的数据资源
2. 避免服务器压力(有兴趣的可以看看[DDoS工具](https://www.zhihu.com/question/22259175))
3. 防止爬虫占用资源导致的用户体验变差
4. 爬虫起诉成功率不高

### 常用反爬虫手段

#### 1. 封掉它

通常一个请求都会带有一定的特征(Header). 常见的识别特征有: User-Agent, IP, session等.

根据这些特征和请求量判断是否为爬虫, 然后直接拉入黑名单.

但是封ip或UA容易造成误伤, 需要谨慎对待. 

#### 2. 限流

限流不同于直接封掉, 限流是根据规则限制用于一定时间内的访问次数.

当达到限流次数的时候, 也不一定会直接禁止访问, 可以通过弹出验证码的方式限制爬虫. 

常见的[限流算法](https://zhuanlan.zhihu.com/p/65900436):

1. 计数器算法
2. 漏桶算法
3. 令牌桶算法

#### 3. 动态加载

对于一些动态网页, 利用JS动态填充技术, 实现内容的动态填充. 

如果简单解析Http会发现返回的信息为空, 而真正有用的信息则影藏在JS文件中, 或者通过ajax请求得到. 这种情况需要进行完全模拟终端用户的正常访问请求, 以及浏览动作, 在浏览器端重现用户行为, 才能够获取到所需要的信息.

#### 4. 加密与混淆

数据加密混淆的方式有很多种, 国内主流的网站(淘宝, 天猫, 新浪等)基本都采用了特殊的数据混淆加密的收到, 本地数据均为混淆后的数据无法直接采集使用, 需要开发人员进行分析, 找出混淆的规律, 再利用解析器来提取出有效信息.

## 反反爬虫

爬虫, 反爬虫, 反反爬虫之间的斗争永无止境... 通常都是爬虫会获取胜利, 除非你不再提供服务, 否则只要能在互联网上访问的到, 就可能会被爬取, 只是看爬虫的效率高低而且. 

下面介绍一个反反爬虫的工具

### 反反爬虫之无头浏览器

无头浏览器(Headless Browser)是指没有图形用户界面(GUI)的web浏览器, 通常是通过编程或命令行界面来控制的.

无头浏览器初衷是做前端的自动化测试的, 然后就慢慢发展成了爬虫工具. 果然人类的智慧是无穷的.

在此之前先了解一下浏览器处理页面的过程:

1. 处理HTML脚本, 生成DOM树

2. 处理CSS脚本, 生成CSSOM树(DOM和CSSOM是独立的数据结构)

3. 将DOM树和CSSOM树合并为渲染树

4. 对渲染树中的内容进行布局, 计算每个节点的几何外观

5. 将渲染树中的每个节点绘制到屏幕中

无头浏览器实际上是节约了4, 5的时间. 它可以像一个真实使用者一样操作浏览器. 这样可以避免上面提到的动态加载和加密混淆的问题.

无头浏览器很多，包括但不限于:

- PhantomJS, 基于 Webkit
- SlimerJS, 基于 Gecko
- HtmlUnit, 基于 Rhnio
- TrifleJS, 基于 Trident
- Splash, 基于 Webkit

当然无头浏览器也不是万能的, 有很多方法可以检测到, 有兴趣可以自己研究一下.

## 编写简单的爬虫

### [Web Scraper](https://webscraper.io/)

网上有很多web scraper的入门教程, 这里就不在累述, 放一个爬取淘宝搜索结果的site map.

主要要注意的就是HTML Element的层次问题.

```json
{
    "_id": "taobao-switch",
    "startUrl": [
        "https://s.taobao.com/search?q=switch"
    ],
    "selectors": [
        {
            "id": "itemList",
            "type": "SelectorElement",
            "parentSelectors": [
                "_root"
            ],
            "selector": "#mainsrp-itemlist",
            "multiple": false,
            "delay": 0
        },
        {
            "id": "items",
            "type": "SelectorElement",
            "parentSelectors": [
                "itemList"
            ],
            "selector": ".item.J_MouserOnverReq",
            "multiple": true,
            "delay": 0
        },
        {
            "id": "title",
            "type": "SelectorText",
            "parentSelectors": [
                "items"
            ],
            "selector": ".title .J_ClickStat",
            "multiple": false,
            "regex": "",
            "delay": 0
        },
        {
            "id": "price",
            "type": "SelectorText",
            "parentSelectors": [
                "items"
            ],
            "selector": ".price strong",
            "multiple": false,
            "regex": "",
            "delay": 0
        },
        {
            "id": "shop",
            "type": "SelectorText",
            "parentSelectors": [
                "items"
            ],
            "selector": ".shopname",
            "multiple": false,
            "regex": "",
            "delay": 0
        },
        {
            "id": "location",
            "type": "SelectorText",
            "parentSelectors": [
                "items"
            ],
            "selector": ".location",
            "multiple": false,
            "regex": "",
            "delay": 0
        },
        {
            "id": "deal-cnt",
            "type": "SelectorText",
            "parentSelectors": [
                "items"
            ],
            "selector": ".deal-cnt",
            "multiple": false,
            "regex": "",
            "delay": 0
        },
        {
            "id": "pic",
            "type": "SelectorImage",
            "parentSelectors": [
                "items"
            ],
            "selector": ".pic .img",
            "multiple": false,
            "delay": 0
        }
    ]
}
```



## 后记

爬虫有风险, 入坑需谨慎!

相关案例请自行百度

TO BE CONTINUE

