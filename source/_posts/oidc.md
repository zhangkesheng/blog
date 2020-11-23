---
title: OIDC
date: 2020-11-23 15:11:51
tags:
  - auth
  - level0
categories: 笔记
keywords: OIDC,OAuth2
desc: OIDC授权流程, Oauth2授权流程
---

# OIDC(OpenId Connect)
-- OIDC授权流程

## 介绍

### OIDC

OIDC是一套基于OAuth2.0的身份认证协议, 也可以说是OAuth2.0的超集. 在OAuth2.0的基础上添加`id_token`, 集成了授权和认证两个部分. 

### OAuth2

OAuth2.0是一个授权协议, 主要用来颁发用于验证用户身份的令牌(token). 现在很多平台都提供了基于OAuth2协议的登录方式.

### 术语

* End-User: 人类用户.
* ID Token: JWT, 包含用户授权的信息, 也**可能**有其他一些信息.
* Identity: 实体相关的属性集.
* OP: OpenId Provider, 用户认证信息的提供方.
* RP: Replying Party, 用户认证信息的消费方.
* UserInfo Endpoint: 受保护的信息, 通过`access_token`获取相应`scope`的信息

## 工作流程

OIDC的授权流程主要分为隐式模式, 授权码模式和混合模式3种, 其中隐式模式和混合模式会直接返回`access_token`, 有token泄漏的风险. 授权码模式是大部分平台选择使用的模式, 这里也主要介绍一下授权码模式.

### 授权码方式的授权

授权码方式是, 授权成功后授权端先颁发一个`code`, 再用`code`换取`token`. 

正常来说, `code`具有**很短的时效性**, 并且只能使用**一次**.

OIDC与OAuth2的授权码方式的区别是, OIDC会多提供`id_token`的信息, `id_token`使用jwt进行加密, 包含了用户的可公开信息. 具体包含信息需要请第三方服务文档.

#### 流程

下面是实际业务的流程, 可能与标准流程有些差别.![OAuth2.0](https://blog-1252854030.cos.ap-chengdu.myqcloud.com/oidc/OAuth2.0.jpg)

步骤:

1. 用户发起授权
2. 服务端根据配置生成授权链接, 并跳转到第三方登录平台.
3. 第三方服务调起用户授权
4. 用户授权成功, 第三方服务带着code跳转回发起授权方
5. web端/服务端(_取决于跳转回web端或服务端_)使用code获取用户token并保存
6. 服务端下发`Authorization`给web端, 用户登录成功

#### 发起授权的请求参数说明

* scope: 必选, 授权请求的授权范围
* response_type: 必选, 授权码方式传入`code`
* client_id: 必选, 从第三方平台获取
* redirect_url: 必选, 大部分平台会要求在设置的白名单内
* state: 可选, 会在授权后原样返回

TO BE CONTINUE

参考资料:

1. [Final: OpenID Connect Core 1.0 incorporating errata set 1](https://openid.net/specs/openid-connect-core-1_0.html)
2. [OAuth 2.0 的四种方式 - 阮一峰的网络日志 (ruanyifeng.com)](http://www.ruanyifeng.com/blog/2019/04/oauth-grant-types.html)