---
title: 部署高可用的k8s集群
date: 2018-01-25 13:58:57
tags: 笔记
categories: Kubernetes
---

# Kubernetes HA

> 摘自 [在CentOS上部署kubernetes1.6集群](https://rootsongjc.gitbooks.io/kubernetes-handbook/content/practice/install-kbernetes1.6-on-centos.html)



## 创建TLS证书和密钥

### 安装CFSSL(源码包安装)

```shell
wget https://pkg.cfssl.org/R1.2/cfssl_linux-amd64
chmod +x cfssl_linux-amd64
mv cfssl_linux-amd64 /usr/local/bin/cfssl

wget https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64
chmod +x cfssljson_linux-amd64
mv cfssljson_linux-amd64 /usr/local/bin/cfssljson

wget https://pkg.cfssl.org/R1.2/cfssl-certinfo_linux-amd64
chmod +x cfssl-certinfo_linux-amd64
mv cfssl-certinfo_linux-amd64 /usr/local/bin/cfssl-certinfo

export PATH=/usr/local/bin:$PATH
```

### 创建CA

#### CA配置文件

```shell
mkdir /root/ssl
cd /root/ssl
cfssl print-defaults config > config.json
cfssl print-defaults csr > csr.json
# 根据config.json文件的格式创建如下的ca-config.json文件
# 过期时间设置成了 87600h
cat > ca-config.json <<EOF
{
  "signing": {
    "default": {
      "expiry": "87600h"
    },
    "profiles": {
      "kubernetes": {
        "usages": [
            "signing",
            "key encipherment",
            "server auth",
            "client auth"
        ],
        "expiry": "87600h"
      }
    }
  }
}
EOF
```

> - `ca-config.json`：可以定义多个 profiles，分别指定不同的过期时间、使用场景等参数；后续在签名证书时使用某个 profile；
> - `signing`：表示该证书可用于签名其它证书；生成的 ca.pem 证书中 `CA=TRUE`；
> - `server auth`：表示client可以用该 CA 对server提供的证书进行验证；
> - `client auth`：表示server可以用该CA对client提供的证书进行验证；

#### 创建CA证书签名请求

```shell
cat > ca-csr.json <<EOF
{
  "CN": "kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "ST": "BeiJing",
      "L": "BeiJing",
      "O": "k8s",
      "OU": "System"
    }
  ]
}
EOF
```

> - "CN"：`Common Name`，kube-apiserver 从证书中提取该字段作为请求的用户名 (User Name)；浏览器使用该字段验证网站是否合法；
> - "O"：`Organization`，kube-apiserver 从证书中提取该字段作为请求用户所属的组 (Group)；

#### 生成 CA 证书和私钥

```shell
$ cfssl gencert -initca ca-csr.json | cfssljson -bare ca
$ ls ca*
ca-config.json  ca.csr  ca-csr.json  ca-key.pem  ca.pem
```

### 创建kubernetes证书

#### 创建 kubernetes 证书签名请求文件

```shell
cat kubernetes-csr.json <<EOF
{
    "CN": "kubernetes",
    "hosts": [
      "127.0.0.1",
      "172.20.0.112",
      "172.20.0.113",
      "172.20.0.114",
      "172.20.0.115",
      "10.254.0.1",
      "kubernetes",
      "kubernetes.default",
      "kubernetes.default.svc",
      "kubernetes.default.svc.cluster",
      "kubernetes.default.svc.cluster.local"
    ],
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
        {
            "C": "CN",
            "ST": "BeiJing",
            "L": "BeiJing",
            "O": "k8s",
            "OU": "System"
        }
    ]
}
EOF
```

> - 如果 hosts 字段不为空则需要指定授权使用该证书的 **IP 或域名列表**，由于该证书后续被 `etcd` 集群和 `kubernetes master` 集群使用，所以上面分别指定了 `etcd` 集群、`kubernetes master` 集群的主机 IP 和 **kubernetes 服务的服务 IP**（一般是 `kube-apiserver` 指定的 `service-cluster-ip-range` 网段的第一个IP，如 10.254.0.1。
> - hosts 中的内容可以为空，即使按照上面的配置，向集群中增加新节点后也不需要重新生成证书。

#### 生成 kubernetes 证书和私钥

```shell
$ cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes kubernetes-csr.json | cfssljson -bare kubernetes
$ ls kubernetes*
kubernetes.csr  kubernetes-csr.json  kubernetes-key.pem  kubernetes.pem
```

### 创建admin证书

#### 创建 admin 证书签名请求文件

```shell
cat admin-csr.json <<EOF
{
  "CN": "admin",
  "hosts": [],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "ST": "BeiJing",
      "L": "BeiJing",
      "O": "system:masters",
      "OU": "System"
    }
  ]
}
EOF
```

> - 后续 `kube-apiserver` 使用 `RBAC` 对客户端(如 `kubelet`、`kube-proxy`、`Pod`)请求进行授权；
> - `kube-apiserver` 预定义了一些 `RBAC` 使用的 `RoleBindings`，如 `cluster-admin` 将 Group `system:masters` 与 Role `cluster-admin` 绑定，该 Role 授予了调用`kube-apiserver` 的**所有 API**的权限；
> - OU 指定该证书的 Group 为 `system:masters`，`kubelet` 使用该证书访问 `kube-apiserver` 时 ，由于证书被 CA 签名，所以认证通过，同时由于证书用户组为经过预授权的 `system:masters`，所以被授予访问所有 API 的权限；

#### 生成 admin 证书和私钥

```shell
$ cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes admin-csr.json | cfssljson -bare admin
$ ls admin*
admin.csr  admin-csr.json  admin-key.pem  admin.pem
```

### 创建 kube-proxy 证书

#### 创建kube-proxy证书签名请求文件

```shell
cat kube-proxy-csr.json <<EOF
{
  "CN": "system:kube-proxy",
  "hosts": [],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "ST": "BeiJing",
      "L": "BeiJing",
      "O": "k8s",
      "OU": "System"
    }
  ]
}
EOF
```

#### 生成 kube-proxy 客户端证书和私钥

```shell
$ cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes  kube-proxy-csr.json | cfssljson -bare kube-proxy
$ ls kube-proxy*
kube-proxy.csr  kube-proxy-csr.json  kube-proxy-key.pem  kube-proxy.pem
```

### 校验证书

#### opsnssl

```shell
openssl x509  -noout -text -in  kubernetes.pem
```



### cfssl-certinfo

```shell
cfssl-certinfo -cert kubernetes.pem
```

### 分发证书

```shell
mkdir -p /etc/kubernetes/ssl
cp *.pem /etc/kubernetes/ssl
```



## 安装kubectl命令行工具

### 下载 kubectl

```shell
wget https://dl.k8s.io/v1.8.4/kubernetes-client-linux-amd64.tar.gz
tar -xzvf kubernetes-client-linux-amd64.tar.gz
cp kubernetes/client/bin/kube* /usr/bin/
chmod a+x /usr/bin/kube*
```

## 创建kubeconfig文件

### 创建TLS Bootsrapping Token

```shell
export BOOTSTRAP_TOKEN=$(head -c 16 /dev/urandom | od -An -t x | tr -d ' ')
cat > /etc/kubernetes/token.csv <<EOF
${BOOTSTRAP_TOKEN},kubelet-bootstrap,10001,"system:kubelet-bootstrap"
EOF
```

### 创建 kubelet bootstrapping kubeconfig 文件

```shell
cd /etc/kubernetes
export KUBE_APISERVER="https://192.168.10.56:6443"
# 设置集群参数
kubectl config set-cluster kubernetes \
  --certificate-authority=/etc/kubernetes/ssl/ca.pem \
  --embed-certs=true \
  --server=${KUBE_APISERVER} \
  --kubeconfig=bootstrap.kubeconfig

# 设置客户端认证参数
kubectl config set-credentials kubelet-bootstrap \
  --token=${BOOTSTRAP_TOKEN} \
  --kubeconfig=bootstrap.kubeconfig

# 设置上下文参数
kubectl config set-context default \
  --cluster=kubernetes \
  --user=kubelet-bootstrap \
  --kubeconfig=bootstrap.kubeconfig

# 设置默认上下文
kubectl config use-context default --kubeconfig=bootstrap.kubeconfig

```

> - `--embed-certs` 为 `true` 时表示将 `certificate-authority` 证书写入到生成的 `bootstrap.kubeconfig` 文件中.
>
>
> - 设置客户端认证参数时**没有**指定秘钥和证书, 后续由 `kube-apiserver` 自动生成.

### 创建 kube-proxy kubeconfig 文件

```shell
# 设置集群参数
kubectl config set-cluster kubernetes \
  --certificate-authority=/etc/kubernetes/ssl/ca.pem \
  --embed-certs=true \
  --server=${KUBE_APISERVER} \
  --kubeconfig=kube-proxy.kubeconfig
# 设置客户端认证参数
kubectl config set-credentials kube-proxy \
  --client-certificate=/etc/kubernetes/ssl/kube-proxy.pem \
  --client-key=/etc/kubernetes/ssl/kube-proxy-key.pem \
  --embed-certs=true \
  --kubeconfig=kube-proxy.kubeconfig
# 设置上下文参数
kubectl config set-context default \
  --cluster=kubernetes \
  --user=kube-proxy \
  --kubeconfig=kube-proxy.kubeconfig
# 设置默认上下文
kubectl config use-context default --kubeconfig=kube-proxy.kubeconfig

```

若上述操作不是在`/etc/kubernetes`中执行, 则需要将生成文件cp到`/etc/kubernetes`中.

## Etcd集群

### 下载并安装etcd

TLS证书沿用kubernetes证书, 如有需要, 可按[创建TLS证书和密钥](#1) 

```shell
wget https://github.com/coreos/etcd/releases/download/v3.2.10/etcd-v3.2.10-linux-amd64.tar.gz
tar -xvf etcd-v3.2.10-linux-amd64.tar.gz
mv etcd-v3.2.10-linux-amd64/etcd* /usr/local/bin
```

或者直接拷贝其他主机的证书

```shell
scp root@192.168.10.56:/etc/kubernetes/ssl/* /etc/kubernetes/ssl/
```



### 创建 etcd 的systamd unit 文件

`/etc/systemd/system/etcd.service`, 注意替换IP地址为你自己的etcd集群的主机IP.

```shell
[Unit]
Description=Etcd Server
After=network.target
After=network-online.target
Wants=network-online.target
Documentation=https://github.com/coreos

[Service]
Type=notify
WorkingDirectory=/var/lib/etcd/
EnvironmentFile=-/etc/etcd/etcd.conf
ExecStart=/usr/local/bin/etcd \
  --name ${ETCD_NAME} \
  --cert-file=/etc/kubernetes/ssl/kubernetes.pem \
  --key-file=/etc/kubernetes/ssl/kubernetes-key.pem \
  --peer-cert-file=/etc/kubernetes/ssl/kubernetes.pem \
  --peer-key-file=/etc/kubernetes/ssl/kubernetes-key.pem \
  --trusted-ca-file=/etc/kubernetes/ssl/ca.pem \
  --peer-trusted-ca-file=/etc/kubernetes/ssl/ca.pem \
  --initial-advertise-peer-urls ${ETCD_INITIAL_ADVERTISE_PEER_URLS} \
  --listen-peer-urls ${ETCD_LISTEN_PEER_URLS} \
  --listen-client-urls ${ETCD_LISTEN_CLIENT_URLS},https://127.0.0.1:2379 \
  --advertise-client-urls ${ETCD_ADVERTISE_CLIENT_URLS} \
  --initial-cluster-token ${ETCD_INITIAL_CLUSTER_TOKEN} \
  --initial-cluster infra1=https://192.168.10.56:2380,infra2=https://192.168.10.57:2380,infra3=https://192.168.10.58:2380 \
  --initial-cluster-state new \
  --data-dir=${ETCD_DATA_DIR}
Restart=on-failure
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
```

> 指定 `etcd` 的工作目录为 `/var/lib/etcd`,数据目录为 `/var/lib/etcd`,需在启动服务前创建这两个目录.

环境变量配置文件`/etc/etcd/etcd.conf`

```shell
cat > /etc/etcd/etcd.conf <<EOF
# [member]
ETCD_NAME=infra1
ETCD_DATA_DIR="/var/lib/etcd"
ETCD_LISTEN_PEER_URLS="https://192.168.10.57:2380"
ETCD_LISTEN_CLIENT_URLS="https://192.168.10.57:2379"

#[cluster]
ETCD_INITIAL_ADVERTISE_PEER_URLS="https://192.168.10.57:2380"
ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster"
ETCD_ADVERTISE_CLIENT_URLS="https://192.168.10.57:2379"
EOF
```

> 在另外的主机上添加同样的文件, 对应的IP改为主机IP, ETCD_NAME也相应修改.

### 启动 etcd 服务

**启动之前, 需要配置防火墙, 否则可能会出现connect refused问题** 

```shell
ufw allow from 192.168.10.56
ufw allow from 192.168.10.57
ufw allow from 192.168.10.58
```

 启动etcd服务

```shell
systemctl daemon-reload
systemctl enable etcd
systemctl start etcd
systemctl status etcd
```

在其他主机上执行上述安装, 配置操作, 启动所有主机上的etcd服务.

### 验证服务

```shell
etcdctl \
  --ca-file=/etc/kubernetes/ssl/ca.pem \
  --cert-file=/etc/kubernetes/ssl/kubernetes.pem \
  --key-file=/etc/kubernetes/ssl/kubernetes-key.pem \
  cluster-health
```

如果直接执行上述命令出现如下错误:

```shelll
cluster may be unhealthy: failed to list members
Error:  client: etcd cluster is unavailable or misconfigured; error #0: malformed HTTP response "\x15\x03\x01\x00\x02\x02"
; error #1: dial tcp 127.0.0.1:4001: getsockopt: connection refused
```

执行`export ETCDCTL_ENDPOINT=https://127.0.0.1:2379`修改ETCDCTL_ENDPOINT环境变量, 之后再次执行, 则可以看到结果.

```shell
member 8f573ae51eacb66 is healthy: got healthy result from https://192.168.10.57:2379
member 42c120089619ad70 is healthy: got healthy result from https://192.168.10.58:2379
member 6bc3e880c7cf3ed7 is healthy: got healthy result from https://192.168.10.56:2379
cluster is healthy
```

结果最后一行为 `cluster is healthy` 时表示集群服务正常.

若是出现member配置错误, 修改配置重新执行前, 需要删除`/var/lib/etcd/member`文件夹

PS: 若有个坑货在你部署的时候乱弄你的服务器, 可能会导致etcd member健康检查成功, 但主机上的etcd也创建成功, 但是连接不上集群. 暂时只想到重新启动所有etcd服务的解决方法:

```shell
# 停止并删除工作目录的member文件夹
systemctl stop etcd.service
systemctl disable etcd.service
rm -r /var/lib/etcd/member/
# 重新启动etcd集群
systemctl daemon-reload
systemctl enable etcd
systemctl start etcd
systemctl status etcd
```



## 部署master集群

安装kubernetes

```shell
wget https://dl.k8s.io/v1.8.4/kubernetes-server-linux-amd64.tar.gz
tar -xzvf kubernetes-server-linux-amd64.tar.gz
cp -r kubernetes/server/bin/{kube-apiserver,kube-controller-manager,kube-scheduler,kubectl,kube-proxy,kubelet} /usr/local/bin/
```

关闭swap

```shell
swapoff -a
```



docker代理, 所以需要设置docker的代理

```shell
mkdir -p /etc/systemd/system/docker.service.d
cat > /etc/systemd/system/docker.service.d/http-proxy.conf << EOF
[Service]
Environment="HTTP_PROXY=http://192.168.32.10:6780"
Environment="HTTPS_PROXY=http://192.168.32.10:6780"
Environment="NO_PROXY=.aliyun.com,.aliyuncs.com,.daocloud.io,.cn,localhost"
EOF
```

> note: no_proxy不支持通配符

## 部署master节点

证书上述已经创建好, 可直接使用

### 下载最新版二进制文件

从 [`CHANGELOG`页面](https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG.md) 下载 `client` 或 `server` tarball 文件

```shell
wget https://dl.k8s.io/v1.8.4/kubernetes-server-linux-amd64.tar.gz
tar -xzvf kubernetes-server-linux-amd64.tar.gz
cd kubernetes
tar -xzvf  kubernetes-src.tar.gz
#将二进制文件拷贝到指定路径
cp -r server/bin/{kube-apiserver,kube-controller-manager,kube-scheduler,kubectl,kube-proxy,kubelet} /usr/local/bin/
```

### 配置和启动kube-apiserver

创建kube-apiserver的service配置文件`/etc/systemd/system/kube-apiserver.service`

```shell
[Unit]
Description=Kubernetes API Service
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
After=network.target
After=etcd.service

[Service]
EnvironmentFile=-/etc/kubernetes/config
EnvironmentFile=-/etc/kubernetes/apiserver
ExecStart=/usr/local/bin/kube-apiserver \
        $KUBE_LOGTOSTDERR \
        $KUBE_LOG_LEVEL \
        $KUBE_ETCD_SERVERS \
        $KUBE_API_ADDRESS \
        $KUBE_API_PORT \
        $KUBELET_PORT \
        $KUBE_ALLOW_PRIV \
        $KUBE_SERVICE_ADDRESSES \
        $KUBE_ADMISSION_CONTROL \
        $KUBE_API_ARGS
Restart=on-failure
Type=notify
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
```

/etc/kubernetes/config:

```shell
cat > /etc/kubernetes/config <<EOF
###
# kubernetes system config
#
# The following values are used to configure various aspects of all
# kubernetes services, including
#
#   kube-apiserver.service
#   kube-controller-manager.service
#   kube-scheduler.service
#   kubelet.service
#   kube-proxy.service
# logging to stderr means we get it in the systemd journal
KUBE_LOGTOSTDERR="--logtostderr=true"

# journal message level, 0 is debug
KUBE_LOG_LEVEL="--v=0"

# Should this cluster be allowed to run privileged docker containers
KUBE_ALLOW_PRIV="--allow-privileged=true"

# How the controller-manager, scheduler, and proxy find the apiserver
#KUBE_MASTER="--master=http://sz-pg-oam-docker-test-001.tendcloud.com:8080"
KUBE_MASTER="--master=http://192.168.10.58:8080"
EOF
```

> 该配置文件同时被kube-apiserver, kube-controller-manager, kube-scheduler, kubelet, kube-proxy使用.

apiserver配置文件`/etc/kubernetes/apiserver`内容为:

```shell
cat > /etc/kubernetes/apiserver <<EOF
###
## kubernetes system config
##
## The following values are used to configure the kube-apiserver
##
#
## The address on the local server to listen to.
#KUBE_API_ADDRESS="--insecure-bind-address=sz-pg-oam-docker-test-001.tendcloud.com"
KUBE_API_ADDRESS="--advertise-address=192.168.10.58 --bind-address=192.168.10.58 --insecure-bind-address=192.168.10.58"
#
## The port on the local server to listen on.
#KUBE_API_PORT="--port=8080"
#
## Port minions listen on
#KUBELET_PORT="--kubelet-port=10250"
#
## Comma separated list of nodes in the etcd cluster
KUBE_ETCD_SERVERS="--etcd-servers=https://192.168.10.56:2379,https://192.168.10.57:2379,https://192.168.10.58:2379"
#
## Address range to use for services
KUBE_SERVICE_ADDRESSES="--service-cluster-ip-range=10.254.0.0/16"
#
## default admission control policies
KUBE_ADMISSION_CONTROL="--admission-control=ServiceAccount,NamespaceLifecycle,NamespaceExists,LimitRanger,ResourceQuota"
#
## Add your own!
KUBE_API_ARGS="--authorization-mode=RBAC --runtime-config=rbac.authorization.k8s.io/v1beta1 --kubelet-https=true --experimental-bootstrap-token-auth --token-auth-file=/etc/kubernetes/token.csv --service-node-port-range=30000-32767 --tls-cert-file=/etc/kubernetes/ssl/kubernetes.pem --tls-private-key-file=/etc/kubernetes/ssl/kubernetes-key.pem --client-ca-file=/etc/kubernetes/ssl/ca.pem --service-account-key-file=/etc/kubernetes/ssl/ca-key.pem --etcd-cafile=/etc/kubernetes/ssl/ca.pem --etcd-certfile=/etc/kubernetes/ssl/kubernetes.pem --etcd-keyfile=/etc/kubernetes/ssl/kubernetes-key.pem --enable-swagger-ui=true --apiserver-count=3 --audit-log-maxage=30 --audit-log-maxbackup=3 --audit-log-maxsize=100 --audit-log-path=/var/lib/audit.log --event-ttl=1h"
EOF
```

> - `--admission-control` 值必须包含 `ServiceAccount`
> - `--bind-address` 不能为 `127.0.0.1`

#### 启动kube-apiserver

```shell
systemctl daemon-reload
systemctl enable kube-apiserver
systemctl start kube-apiserver
systemctl status kube-apiserver
```

### 配置和启动 kube-controller-manager

#### 创建 kube-controller-manager的serivce配置文件

service配置文件`/etc/systemd/system/kube-controller-manager.service`

```shell
[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/GoogleCloudPlatform/kubernetes

[Service]
EnvironmentFile=-/etc/kubernetes/config
EnvironmentFile=-/etc/kubernetes/controller-manager
ExecStart=/usr/local/bin/kube-controller-manager \
        $KUBE_LOGTOSTDERR \
        $KUBE_LOG_LEVEL \
        $KUBE_MASTER \
        $KUBE_CONTROLLER_MANAGER_ARGS
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
```

配置文件`/etc/kubernetes/controller-manager`

```shell
cat > /etc/kubernetes/controller-manager <<EOF
###
# The following values are used to configure the kubernetes controller-manager

# defaults from config and apiserver should be adequate

# Add your own!
KUBE_CONTROLLER_MANAGER_ARGS="--address=127.0.0.1 --service-cluster-ip-range=10.254.0.0/16 --cluster-name=kubernetes --cluster-signing-cert-file=/etc/kubernetes/ssl/ca.pem --cluster-signing-key-file=/etc/kubernetes/ssl/ca-key.pem  --service-account-private-key-file=/etc/kubernetes/ssl/ca-key.pem --root-ca-file=/etc/kubernetes/ssl/ca.pem --leader-elect=true"
EOF
```

#### 启动 kube-controller-manager

```shell
systemctl daemon-reload
systemctl enable kube-controller-manager
systemctl start kube-controller-manager
```



### 配置和启动 kube-scheduler

#### 创建 kube-scheduler的serivce配置文件

serivce文件`/etc/systemd/system/kube-scheduler.service`

```shell
[Unit]
Description=Kubernetes Scheduler Plugin
Documentation=https://github.com/GoogleCloudPlatform/kubernetes

[Service]
EnvironmentFile=-/etc/kubernetes/config
EnvironmentFile=-/etc/kubernetes/scheduler
ExecStart=/usr/local/bin/kube-scheduler \
            $KUBE_LOGTOSTDERR \
            $KUBE_LOG_LEVEL \
            $KUBE_MASTER \
            $KUBE_SCHEDULER_ARGS
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
```

配置文件`/etc/kubernetes/scheduler`

```shell
cat > /etc/kubernetes/scheduler <<EOF
###
# kubernetes scheduler config

# default config should be adequate

# Add your own!
KUBE_SCHEDULER_ARGS="--leader-elect=true --address=127.0.0.1"
EOF
```

> `--address` 值必须为 `127.0.0.1`，因为当前 kube-apiserver 期望 scheduler 和 controller-manager 在同一台机器

#### 启动 kube-scheduler

```shell
systemctl daemon-reload
systemctl enable kube-scheduler
systemctl start kube-scheduler
```



### 验证 master 节点功能

```shelll
$ kubectl get componentstatuses
NAME                 STATUS    MESSAGE              ERROR
scheduler            Healthy   ok                   
controller-manager   Healthy   ok                   
etcd-0               Healthy   {"health": "true"}   
etcd-1               Healthy   {"health": "true"}   
etcd-2               Healthy   {"health": "true"}
```

> 若出现`The connection to the server localhost:8080 was refused - did you specify the right host or port?`错误, 请运行`kubectl --server=192.168.10.56:8080 get componentstatuses`, 自行修改为主机IP.
>
> apiserver不要指定--insecure-bind-address, 则不会出现上述问题.

之后再另外两台主机上启动apiserver, controller-maneger, scheduler.

**记得`cp /etc/kubernetes/token.csv`**



## 部署node节点

### 基础配置

检查前几部生成的ca文件, 及config文件是否都有.

### 安装网络插件Flanneld(可跳过)

下载二进制文件

```shell
wget https://github.com/coreos/flannel/releases/download/v0.9.1/flannel-v0.9.1-linux-amd64.tar.gz
tar -xzvf flannel-v0.9.1-linux-amd64.tar.gz
cp flanneld /usr/bin/
```

`/etc/systemd/system/flanneld.service`

```shell
[Unit]
Description=Flanneld overlay address etcd agent
After=network.target
After=network-online.target
Wants=network-online.target
After=etcd.service
Before=docker.service

[Service]
Type=notify
EnvironmentFile=/etc/sysconfig/flanneld
EnvironmentFile=-/etc/sysconfig/docker-network
ExecStart=/usr/bin/flanneld \
  -etcd-endpoints=${ETCD_ENDPOINTS} \
  -etcd-prefix=${ETCD_PREFIX} \
  $FLANNEL_OPTIONS
ExecStartPost=/usr/libexec/flannel/mk-docker-opts.sh -k DOCKER_NETWORK_OPTIONS -d /run/flannel/docker
Restart=on-failure

[Install]
WantedBy=multi-user.target
RequiredBy=docker.service
```

`/etc/sysconfig/flanneld`配置文件

```she
mkdir /etc/sysconfig
cat > /etc/sysconfig/flanneld <<EOF
# Flanneld configuration options  

# etcd url location.  Point this to the server where etcd runs
ETCD_ENDPOINTS="https://192.168.10.56:2379,https://192.168.10.57:2379,https://192.168.10.58:2379"

# etcd config key.  This is the configuration key that flannel queries
# For address range assignment
ETCD_PREFIX="/kube-centos/network"

# Any additional options that you want to pass
FLANNEL_OPTIONS="-etcd-cafile=/etc/kubernetes/ssl/ca.pem -etcd-certfile=/etc/kubernetes/ssl/kubernetes.pem -etcd-keyfile=/etc/kubernetes/ssl/kubernetes-key.pem"
EOF
```



#### 在etcd中创建网络配置

```shell
etcdctl --endpoints=https://192.168.10.56:2379,https://192.168.10.57:2379,https://192.168.10.558:2379 \
  --ca-file=/etc/kubernetes/ssl/ca.pem \
  --cert-file=/etc/kubernetes/ssl/kubernetes.pem \
  --key-file=/etc/kubernetes/ssl/kubernetes-key.pem \
  mkdir /kube-centos/network
etcdctl --endpoints=https://192.168.10.56:2379,https://192.168.10.57:2379,https://192.168.10.558:2379 \
  --ca-file=/etc/kubernetes/ssl/ca.pem \
  --cert-file=/etc/kubernetes/ssl/kubernetes.pem \
  --key-file=/etc/kubernetes/ssl/kubernetes-key.pem \
  mk /kube-centos/network/config '{"Network":"172.30.0.0/16","SubnetLen":24,"Backend":{"Type":"vxlan"}}'
```

#### 配置Docker

如果你不是使用yum安装的flanneld, 需要执行下载文件解压出的**mk-docker-opts.sh**文件.

这个文件是用来`Generate Docker daemon options based on flannel env file`.

执行`./mk-docker-opts.sh -i`将会生成如下两个文件环境变量文件

重启docker

```shell
service docker stop
dockerd --bip=${FLANNEL_SUBNET} --mtu=${FLANNEL_MTU}
# 设置docker0网桥的IP地址
ifconfig docker0 $FLANNEL_SUBNET
# 环境变量配置
cat > /etc/systemd/system/docker.service.d/flannel.conf <<EOF
[Service]
EnvironmentFile=-/run/flannel/docker
EnvironmentFile=-/run/docker_opts.env
EnvironmentFile=-/run/flannel/subnet.env
EOF
```

### 安装和配置 kubelet

#### 下载最新的 kubelet 和 kube-proxy 二进制文件

```shell
wget https://dl.k8s.io/v1.8.4/kubernetes-server-linux-amd64.tar.gz
tar -xzvf kubernetes-server-linux-amd64.tar.gz
cd kubernetes
tar -xzvf  kubernetes-src.tar.gz
cp -r ./server/bin/{kube-proxy,kubelet} /usr/local/bin/
```

#### 创建 kubelet 的service配置文件

`/etc/systemd/system/kubelet.service`

```shell
[Unit]
Description=Kubernetes Kubelet Server
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
After=docker.service
Requires=docker.service

[Service]
WorkingDirectory=/var/lib/kubelet
EnvironmentFile=-/etc/kubernetes/config
EnvironmentFile=-/etc/kubernetes/kubelet
ExecStart=/usr/local/bin/kubelet \
            $KUBE_LOGTOSTDERR \
            $KUBE_LOG_LEVEL \
            $KUBELET_API_SERVER \
            $KUBELET_ADDRESS \
            $KUBELET_PORT \
            $KUBELET_HOSTNAME \
            $KUBE_ALLOW_PRIV \
            $KUBELET_POD_INFRA_CONTAINER \
            $KUBELET_ARGS
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

kubelet的配置文件`/etc/kubernetes/kubelet`

```shell
cat > /etc/kubernetes/kubelet <<EOF
###
## kubernetes kubelet (minion) config
#
## The address for the info server to serve on (set to 0.0.0.0 or "" for all interfaces)
KUBELET_ADDRESS="--address=192.168.10.58"
#
## The port for the info server to serve on
#KUBELET_PORT="--port=10250"
#
## You may leave this blank to use the actual hostname
KUBELET_HOSTNAME="--hostname-override=192.168.10.58"
#
## location of the api-server已过时
# KUBELET_API_SERVER="--api-servers=http://192.168.10.58:8080"
#
## pod infrastructure container
KUBELET_POD_INFRA_CONTAINER="--pod-infra-container-image=registry.access.redhat.com/rhel7/pod-infrastructure:latest"
#
## Add your own!
# --cgroup-driver=systemd 的配置需要跟docker一样
KUBELET_ARGS="--cgroup-driver=cgroupfs --cluster-dns=10.254.0.2 --experimental-bootstrap-kubeconfig=/etc/kubernetes/bootstrap.kubeconfig --kubeconfig=/etc/kubernetes/kubelet.kubeconfig --require-kubeconfig --cert-dir=/etc/kubernetes/ssl --cluster-domain=cluster.local --hairpin-mode promiscuous-bridge --serialize-image-pulls=false"
EOF
```

> handbook上说, /etc/kubernetes/kubelet.kubeconfig可暂时不创建, 在之后的步骤中会自动创建, 我是直接`cp ~/.kube/config /etc/kubernetes/kulelet.kubeconfg`, config文件是否可以不存在, 之后需要再验证

#### 启动kubelet

```shell
systemctl daemon-reload
systemctl enable kubelet
systemctl start kubelet
systemctl status kubelet
```



### 配置 kube-proxy

#### 创建 kube-proxy 的service配置文件

`/etc/systemd/system/kube-proxy.service`

```shell
[Unit]
Description=Kubernetes Kube-Proxy Server
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
After=network.target

[Service]
EnvironmentFile=-/etc/kubernetes/config
EnvironmentFile=-/etc/kubernetes/proxy
ExecStart=/usr/local/bin/kube-proxy \
        $KUBE_LOGTOSTDERR \
        $KUBE_LOG_LEVEL \
        $KUBE_MASTER \
        $KUBE_PROXY_ARGS
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
```

kube-proxy配置文件`/etc/kubernetes/proxy`

```shell
cat > /etc/kubernetes/proxy <<EOF
###
# kubernetes proxy config

# default config should be adequate

# Add your own!
KUBE_PROXY_ARGS="--bind-address=192.168.10.57 --hostname-override=192.168.10.57 --kubeconfig=/etc/kubernetes/kube-proxy.kubeconfig --cluster-cidr=10.254.0.0/16"
EOF
```

> `--hostname-override` 参数值必须与 kubelet 的值一致，否则 kube-proxy 启动后会找不到该 Node，从而不会创建任何 iptables 规则

#### 启动kube-proxy

```shell
systemctl daemon-reload
systemctl enable kube-proxy
systemctl start kube-proxy
systemctl status kube-proxy
```



## 安装dashboard

参考: https://zhangkesheng.github.io/2017/11/16/Kubernetes-Install/#Kebernetes-Dashboard

** 此方法采用二进制安装, 存在升级问题等一些问题, 下一篇会讲解如何用docker-compose的方式安装 **

未完待续...




