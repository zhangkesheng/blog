---
title: kubernetes-istio-v2
date: 2018-06-25 15:00:24
tags:
  - kubernetes
  - istio
categories: 笔记
---

# kubernetes1.10集成istio 8.0 

本来已经部署好istio0.5, 以为升级一下就可以了, 实际操作起来才发现, 中间多了这么多坑.

> istio 0.5的部署请参考[kubernetes-istio](/2018/04/12/kubernetes-istio/)

[TOC]

## 部署istio

### 下载最新版安装文件

~~~bash
curl -L https://git.io/getLatestIstio | sh -
~~~

### helm部署istio

~~~bash
cd istio-VERSION # 版本不一样, 文件夹名也不一样
# 手动注入模式
helm template install/kubernetes/helm/istio --name istio --namespace istio-system --set sidecarInjectorWebhook.enabled=false > $HOME/istio.yaml
# 或自动注入模式, 由于需要修改k8s配置, 所以选择手动
# helm template install/kubernetes/helm/istio --name istio --namespace istio-system > $HOME/istio.yaml
# 部署
kubectl create namespace istio-system
kubectl apply -f $HOME/istio.yaml
~~~

## 配置egress

istio0.8的egressRule与0.5的配置有很大的改变

### ServiceEntry

官方文档上推荐使用这个方式来创建egressRule, 就目前来看, serviceEntry只支持HTTP/HTTPS, TCP类型需要用到之前的egressRule, 但是试了一下,  istio0.5的egressRule配置并不会生效, 这个需要之后验证.

### Calling external services directly(直接调用外部服务 )

目前, 采用直接调用外部服务的方式. 不需要配置其他, 只要要修改istio-sidecar-injector configmap即可.

~~~bash
helm template install/kubernetes/helm/istio --name istio --namespace istio-system --set sidecarInjectorWebhook.enabled=false --set global.proxy.includeIPRanges="172.16.0.0/18" -x templates/sidecar-injector-configmap.yaml | kubectl apply -f -
~~~

istio 0.8 egress rule 文档地址 [Control Egress Traffic >>](https://istio.io/docs/tasks/traffic-management/egress/)

之后的部署及相关配套设施的部署与[kubernetes-istio](/2018/04/12/kubernetes-istio/)相同.

## INGRESS

istio0.8 将ingress改为了gateway, 暂时没有使用gateway的功能, 依旧使用的是ingress.

## 记录坑

### ingress

~~~yaml
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: INGRESS_NAME
  namespace: NAMESPACE
  annotations: #添加istio annotations
    kubernetes.io/ingress.class: "istio"
spec:
  rules:
  - host: HOST
    http:
      paths:
      - path: [/contextPath]/.*
        backend:
          serviceName: service-name
          servicePort: 80
~~~

**http.paths.path记得用.*, 千万不要只写一个 * 号!!! **

**http.paths.path记得用.*, 千万不要只写一个 * 号!!! **

**http.paths.path记得用.*, 千万不要只写一个 * 号!!! **

### selector version

selector 添加新的标签, 会导致旧的副本集不会被删除, 也不关联在deployment下, 这样接口访问会有不同版本的问题. 需要在service里添加相应的selector, 或使用istio的路由规则.
