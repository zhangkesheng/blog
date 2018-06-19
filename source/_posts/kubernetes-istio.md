---
title: kubernetes-istio
date: 2018-04-12 18:15:04
tags: 笔记
categories: Kubernetes
---
# kubernetes-istio

kubernetes集成istio

> 原文地址: http://istio.doczh.cn/docs/setup/kubernetes/quick-start.html
>
> 基于现有的kubernetes集群安装istio(**1.7.3 后更高版本, 并且启用了[RBAC ](https://kubernetes.io/docs/admin/authorization/rbac/)**)

## 介绍Istio

### Envoy

Istio核心组件, 包含了动态服务发现, 负载均衡, TLS终止, HTTP/2&gRPC代理, 熔断器, 健康检查, 基于百分比流量拆分的分段推出, 故障注入和丰富指标等功能.

Envoy被部署为sidecar, 和对应的服务在同一个pod中.

Mixer

负责服务网格上执行访问控制和使用策略, 并从Envoy代理和其他服务收集遥测数据.

Pilot

负责收集和验证配置并将其传播到各种Istio组件.

Istio-Auth

提供强大的服务间认证和终端用户认证, 使用交互TLS, 内置身份和证书管理.

## 安装Istio

#### 下载最新版

```bash
curl -L https://git.io/getLatestIstio | sh -
```

或者手动下载 [istio](https://github.com/istio/istio/releases), 解压

下载最新版并解压, 需要手动将`istioctl`复制到PATH路径下, 或将 `istioctl` 客户端二进制文件加到 PATH 中.

**进入istio文件夹后操作**

#### 安装 Istio

```bash
kubectl apply -f install/kubernetes/istio.yaml
```

> 注意：如果运行的集群不支持外部负载均衡器, `istio-ingress` 服务的 `EXTERNAL-IP` 显示`<pending>`. 必须改为使用 NodePort service 或者 端口转发方式来访问应用程序

#### 验证安装

```bash
kubectl get svc -n istio-system
kubectl get pods -n istio-system
```

pod状态都为Running即成功.

#### 部署应用

#### 准备

```yaml
apiVersion: config.istio.io/v1alpha2
kind: EgressRule
metadata:
  name: mysql
  namespace: default
spec:
  destination:
      service: MYSQL_IP
  ports:
      - port: 3306
        protocol: tcp
```

```yaml
apiVersion: config.istio.io/v1alpha2
kind: EgressRule
metadata:
  name: redis
  namespace: default
spec:
  destination:
      service: REDIS_IP
  ports:
      - port: 6379
        protocol: tcp
```

```yaml
apiVersion: config.istio.io/v1alpha2
kind: EgressRule
metadata:
  name: es
  namespace: default
spec:
  destination:
      service: ES_IP
  ports:
      - port: 9300
        protocol: tcp
```



#### 部署

我们并没有启动istio-initializer, 所以需要手动注入Envoy

```bash
kubectl create -f <(istioctl kube-inject -f DEPLOYMENT.yaml)
```

若服务已创建需要使用`kubectl apply`

```bash
kubectl apply -f <(istioctl kube-inject -f DEPLOYMENT.yaml)
```



部署相应的service和ingress, 可先参考[神坑](#部署istio项目时遇到的坑), 避免一些重复的坑.

## 配套设施

### 1.  zipkin

部署

```bash
kubectl apply -f install/kubernetes/addons/zipkin.yaml
```

**通过istio-ingress访问**

创建ingress

```yaml
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: zipkin
  namespace: istio-system
  annotations:
    kubernetes.io/ingress.class: "istio"
spec:
  rules:
  - http:
      paths:
      - path: /zipkin/.*
        backend:
          serviceName: zipkin
          servicePort: 9411 
```

访问

http://hostip:31100/zipkin/

### 2. Prometheus

部署

```bash
kubectl apply -f install/kubernetes/addons/prometheus.yaml
```

**通过nodePort访问**

```bas
kubectl -n istio-system edit service prometheus
```

访问

http://hostip:31701/graph

**创建prometheus数据收集规则请参考:**

http://istio.doczh.cn/docs/tasks/telemetry/metrics-logs.html

http://istio.doczh.cn/docs/tasks/telemetry/tcp-metrics.html

### 3. grafana

部署

```bash
 kubectl apply -f install/kubernetes/addons/grafana.yaml
```

**通过nodePort访问**

```bash
kubectl -n istio-system edit service grafana
```

访问

http://hostip:31702/

### 4. servicegraph

Servicegraph服务是一个示例服务, 他提供了一个生成和展现Service Mesh中服务关系的功能, 包含如下几个服务端点: 

- `/graph`: 提供了servicegraph的JSON序列化展示
- `/dotgraph`: 提供了servicegraph的Dot序列化展示
- `/dotviz`: 提供了servicegraph的可视化展示

所有的端点都可以使用一个可选参数`time_horizon`, 这个参数控制图形生成的时间跨度.

另外一个可选参数就是`filter_empty=true`, 在`time_horizon`所限定的时间段内, 这一参数可以限制只显示流量大于零的node和edge.

Servicegraph示例构建在Prometheus查询之上.

安装

```bash
kubectl apply -f install/kubernetes/addons/servicegraph.yaml
```

**通过nodePort访问**

```bash
kubectl -n istio-system edit service servicegraph
```

访问

http://hostip:31703/dotviz



## 部署istio项目时遇到的坑

1. istio部署服务一直连不上数据库, 我不论用什么方法都没用, istio都删了重新装的不行, 原因是ip写错了... 

   要创建egress-role

   ```bash
   apiVersion: config.istio.io/v1alpha2
   kind: EgressRule
   metadata:
     name: mysql
     namespace: default
   spec:
     destination:
         service: <MySQL instance IP>
     ports:
         - port: <MySQL instance port>
           protocol: tcp
   ```

2. istio-ingress 404

   1. path需要配置成/qingdaoliuyi/.*, 否则只能访问/qingdaoliuyi, 路径下的css, js会404. [istio-ingress](http://istio.doczh.cn/docs/tasks/traffic-management/ingress.html)
   2. istio-ingress仅对service中name是`http`的ports起作用. 相关[issue](https://github.com/istio/issues/issues/88)

3. deployment部署后, 删除istio并重新部署, 更新deployment后egress无效?(待验证问题)

4. 发送请求到外部HTTPS服务

   外部的HTTPS服务必须可以通过HTTP访问，在请求中指定端口：

   ```
   curl http://www.google.com:443
   ```

最后, 由于egress对于https的支持还有一定的问题, 所以暂时没有将istio加进我们kubernetes里.