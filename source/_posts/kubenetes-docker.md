---
title: Kubernetes安装脚本(docker-compose)
date: 2018-01-25 14:17:17
tags: 笔记
categories: Kubernetes
---

# Kubernetes安装脚本



## 环境

节点列表

NODE1：127.0.0.1

NODE2：127.0.0.2

NODE3：127.0.0.3

## Docker daemon config

```bash
cat >/etc/docker/daemon.json <<EOF
{
  "registry-mirrors": ["https://1.mirror.aliyuncs.com"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m"
  },
  "bridge": "docker0"
}
EOF
```

## Install cfssl

```bash
# Install cfssl utils for generating certs.
for bin in cfssl cfssljson cfssl-certinfo; do
  curl -sSL -o /usr/local/bin/${bin} https://pkg.cfssl.org/R1.2/${bin}_linux-amd64
  chmod +x /usr/local/bin/${bin}
done
```

## Generate config

```bash
cat >ca-config.json <<EOF
{
  "signing": {
    "default": {
        "usages": [
          "signing",
          "key encipherment",
          "server auth",
          "client auth"
        ],
        "expiry": "876000h"
    }
  }
}
EOF
```

## Set Env

```bash
export NODE1="127.0.0.1"
export NODE2="127.0.0.2"
export NODE3="127.0.0.3"
export MASTER_IPS="${NODE1},${NODE2},${NODE3}"
export ETCD_INITIAL_CLUSTER="etcd-01=https://${NODE1}:2380,etcd-02=https://${NODE2}:2380,etcd-03=https://${NODE3}:2380"
export ETCD_SERVERS="https://${NODE1}:2379,https://${NODE2}:2379,https://${NODE3}:2379"
export ETCD_INITIAL_CLUSTER_TOKEN='myzd-prod-etcd-cluster-token'
export KUBE_API_IP=${NODE1}
export KUBE_API_CLUSTER_IP="172.16.0.1"
export CLUSTER_CIDR="172.16.64.0/18"
export SERVICE_CLUSTER_CIDR="172.16.0.0/18"
export CLUSTER_DNS="172.16.0.3"
export KUBE_API_HA_IP="127.0.0.4"
export KUBE_API_HA_HOST="https://${KUBE_API_HA_IP}"
## set eviction_head
export EVICTION_HARD="memory.available<10%,nodefs.available<10%"
```

```bash
export CURRENT_NODE=${NODE1}
export ETCD_NAME="etcd-01"
```

```bash
export CURRENT_NODE=${NODE2}
export ETCD_NAME="etcd-02"
```

```bash
export CURRENT_NODE=${NODE3}
export ETCD_NAME="etcd-03"
```

## Generate etcd certificates

```bash
# Generate CA certs for etcd
cat >etcd-cs-ca-csr.json <<EOF
{
    "CN": "MYZD etcd CS CA",
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
        {
            "C": "CN",
            "ST": "Shanghai",
            "L": "Shanghai",
            "O": "MYZD",
            "OU": "System"
        }
    ],
    "CA": { "Expiry": "876000h" }
}
EOF
cfssl gencert -initca etcd-cs-ca-csr.json | cfssljson -bare etcd-cs-ca

cat >etcd-peer-ca-csr.json <<EOF
{
    "CN": "MYZD etcd peer CA",
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
        {
            "C": "CN",
            "ST": "Shanghai",
            "L": "Shanghai",
            "O": "MYZD",
            "OU": "System"
        }
    ],
    "CA": { "Expiry": "876000h" }
}
EOF
cfssl gencert -initca etcd-peer-ca-csr.json | cfssljson -bare etcd-peer-ca

# Generate peer certificate
echo '{"CN":"etcd-peer","hosts":[""],"key":{"algo":"rsa","size":2048}}' |\
cfssl gencert -ca=etcd-peer-ca.pem -ca-key=etcd-peer-ca-key.pem -config=ca-config.json \
-hostname="${MASTER_IPS},etcd-01,etcd-02,etcd-03" - |\
cfssljson -bare etcd-peer

# Generate server certificate
echo '{"CN":"etcd-server","hosts":[""],"key":{"algo":"rsa","size":2048}}' |\
cfssl gencert -ca=etcd-cs-ca.pem -ca-key=etcd-cs-ca-key.pem -config=ca-config.json \
-hostname="${MASTER_IPS},127.0.0.1,localhost,etcd-01,etcd-02,etcd-03" - |\
cfssljson -bare etcd-server

# Generate client certificates
echo '{"CN":"etcd-client","hosts":[""],"key":{"algo":"rsa","size":2048}}' |\
cfssl gencert -ca=etcd-cs-ca.pem -ca-key=etcd-cs-ca-key.pem -config=ca-config.json - |\
cfssljson -bare etcd-client

# Copy certs tp etcd config directory(/etc/etcd on each peer)
mkdir etcd
cp etcd-cs-ca.pem etcd
cp etcd-peer-ca.pem etcd
cp etcd-peer.pem etcd
cp etcd-peer-key.pem etcd
cp etcd-server.pem etcd
cp etcd-server-key.pem etcd
cp etcd-client.pem etcd
cp etcd-client-key.pem etcd
```

# Generate kubernete certificates

```bash
# Generate CA certs for kebelet
cat >kubelet-ca-csr.json <<EOF
{
    "CN": "MYZD kubelet CA",
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
        {
            "C": "CN",
            "ST": "Shanghai",
            "L": "Shanghai",
            "O": "MYZD",
            "OU": "Kubernetes"
        }
    ],
    "CA": { "Expiry": "876000h" }
}
EOF
cfssl gencert -initca kubelet-ca-csr.json | cfssljson -bare kubelet-ca

# Generate kubelet-client rsa key pair
cat >kubelet-client-csr.json <<EOF
{
  "CN": "kubelet-client",
  "hosts": [],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "ST": "Shanghai",
      "L": "Shanghai",
      "O": "system:kebulet",
      "OU": "Kubernetes"
    }
  ]
}
EOF
cfssl gencert -ca=kubelet-ca.pem -ca-key=kubelet-ca-key.pem -config=ca-config.json kubelet-client-csr.json | cfssljson -bare kubelet-client-certificate

# Generate CA certs for kubernetes
cat >kubernetes-ca-csr.json <<EOF
{
    "CN": "MYZD Kubernetes CA",
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
        {
            "C": "CN",
            "ST": "Shanghai",
            "L": "Shanghai",
            "O": "MYZD",
            "OU": "System"
        }
    ],
    "CA": { "Expiry": "876000h" }
}
EOF
cfssl gencert -initca kubernetes-ca-csr.json | cfssljson -bare kube-ca
# Generate service account rsa key pair
openssl genrsa -out kube-service-account.key 4096

cat >kube-admin-csr.json <<EOF
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
      "ST": "Shanghai",
      "L": "Shanghai",
      "O": "system:masters",
      "OU": "Kubernetes"
    }
  ]
}
EOF
cfssl gencert -ca=kube-ca.pem -ca-key=kube-ca-key.pem -config=ca-config.json \
kube-admin-csr.json | cfssljson -bare kube-admin

cat >kube-controller-csr.json <<EOF
{
  "CN": "system:kube-controller-manager",
  "hosts": [],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "ST": "Shanghai",
      "L": "Shanghai",
      "O": "system",
      "OU": "Kubernetes"
    }
  ]
}
EOF
cfssl gencert -ca=kube-ca.pem -ca-key=kube-ca-key.pem -config=ca-config.json \
kube-controller-csr.json | cfssljson -bare kube-controller

cat >kube-scheduler-csr.json <<EOF
{
  "CN": "system:kube-scheduler",
  "hosts": [],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "ST": "Shanghai",
      "L": "Shanghai",
      "O": "system",
      "OU": "Kubernetes"
    }
  ]
}
EOF
cfssl gencert -ca=kube-ca.pem -ca-key=kube-ca-key.pem -config=ca-config.json \
kube-scheduler-csr.json | cfssljson -bare kube-scheduler

cat >kube-proxy-csr.json <<EOF
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
      "ST": "Shanghai",
      "L": "Shanghai",
      "O": "system",
      "OU": "Kubernetes"
    }
  ]
}
EOF
cfssl gencert -ca=kube-ca.pem -ca-key=kube-ca-key.pem -config=ca-config.json \
kube-proxy-csr.json | cfssljson -bare kube-proxy

cat >kubelet-csr.json <<EOF
{
  "CN": "system:kubelet",
  "hosts": [],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "ST": "Shanghai",
      "L": "Shanghai",
      "O": "system:node",
      "OU": "Kubernetes"
    }
  ]
}
EOF
cfssl gencert -ca=kube-ca.pem -ca-key=kube-ca-key.pem -config=ca-config.json \
kubelet-csr.json | cfssljson -bare kubelet

# Generate apiserver https certs
echo '{"CN":"kube-api","hosts":[""],"key":{"algo":"rsa","size":2048}}' |\
cfssl gencert -ca=kube-ca.pem -ca-key=kube-ca-key.pem -config=ca-config.json \
-hostname="${MASTER_IPS},127.0.0.1,localhost,kube-api,${KUBE_API_CLUSTER_IP},${KUBE_API_HA_IP}" - |\
cfssljson -bare kube-api

# Copy certs to kubernetes config directory(/etc/kubernetes on each master)
mkdir kubernetes
cp kube-ca.pem kubernetes
cp kubelet.pem kubernetes
cp kubelet-key.pem kubernetes
cp kubelet-ca.pem kubernetes
# masters only
cp etcd-cs-ca.pem kubernetes
cp etcd-client.pem kubernetes
cp etcd-client-key.pem kubernetes
cp kube-service-account.key kubernetes
cp kube-api.pem kubernetes
cp kube-api-key.pem kubernetes
cp kube-controller.pem kubernetes
cp kube-controller-key.pem kubernetes
cp kube-scheduler.pem kubernetes
cp kube-scheduler-key.pem kubernetes
cp kube-proxy.pem kubernetes
cp kube-proxy-key.pem kubernetes
cp kubelet-client-certificate.pem kubernetes
cp kubelet-client-certificate-key.pem kubernetes

mkdir bak
cp *.pem bak
```

# Generate kubernete configurations

```bash
# Generate config for kubernetes components.
cat >kubernetes/kubecfg-controller.yml <<EOF
apiVersion: v1
kind: Config
clusters:
- cluster:
    api-version: v1
    certificate-authority: /etc/kubernetes/kube-ca.pem
    server: "${KUBE_API_HA_HOST}"
  name: "local"
contexts:
- context:
    cluster: "local"
    user: "kube-controller"
  name: "Default"
current-context: "Default"
users:
- name: "kube-controller"
  user:
    client-certificate: /etc/kubernetes/kube-controller.pem
    client-key: /etc/kubernetes/kube-controller-key.pem
EOF

cat >kubernetes/kubecfg-scheduler.yml <<EOF
apiVersion: v1
kind: Config
clusters:
- cluster:
    api-version: v1
    certificate-authority: /etc/kubernetes/kube-ca.pem
    server: "${KUBE_API_HA_HOST}"
  name: "local"
contexts:
- context:
    cluster: "local"
    user: "kube-scheduler"
  name: "Default"
current-context: "Default"
users:
- name: "kube-scheduler"
  user:
    client-certificate: /etc/kubernetes/kube-scheduler.pem
    client-key: /etc/kubernetes/kube-scheduler-key.pem
EOF

cat >kubernetes/kubecfg-proxy.yml <<EOF
apiVersion: v1
kind: Config
clusters:
- cluster:
    api-version: v1
    certificate-authority: /etc/kubernetes/kube-ca.pem
    server: "${KUBE_API_HA_HOST}"
  name: "local"
contexts:
- context:
    cluster: "local"
    user: "kube-proxy"
  name: "Default"
current-context: "Default"
users:
- name: "kube-proxy"
  user:
    client-certificate: /etc/kubernetes/kube-proxy.pem
    client-key: /etc/kubernetes/kube-proxy-key.pem
EOF

cat >kubernetes/kubecfg-kubelet.yml <<EOF
apiVersion: v1
kind: Config
clusters:
- cluster:
    api-version: v1
    certificate-authority: /etc/kubernetes/kube-ca.pem
    server: "${KUBE_API_HA_HOST}"
  name: "local"
contexts:
- context:
    cluster: "local"
    user: "kubelet"
  name: "Default"
current-context: "Default"
users:
- name: "kubelet"
  user:
    client-certificate: /etc/kubernetes/kubelet.pem
    client-key: /etc/kubernetes/kubelet-key.pem
EOF
```

## Run basic services on each node

```bash
# daemons with docker-compose files
mkdir daemons

cat >daemons/etcd.yml <<EOF
version: '2'
services:
  etcd:
    image: bestmike007/etcd:v3.2.13
    container_name: etcd
    restart: always
    network_mode: host
    volumes:
    - /srv/etcd:/${ETCD_NAME}.etcd
    - /etc/etcd:/certs:ro
    environment:
      ETCD_NAME: ${ETCD_NAME}
      ETCD_INITIAL_ADVERTISE_PEER_URLS: https://${CURRENT_NODE}:2380
      ETCD_LISTEN_PEER_URLS: https://${CURRENT_NODE}:2380
      ETCD_ADVERTISE_CLIENT_URLS: https://${CURRENT_NODE}:2379
      ETCD_LISTEN_CLIENT_URLS: https://${CURRENT_NODE}:2379,https://127.0.0.1:2379
      ETCD_INITIAL_CLUSTER_TOKEN: ${ETCD_INITIAL_CLUSTER_TOKEN}
      ETCD_INITIAL_CLUSTER: ${ETCD_INITIAL_CLUSTER}
      ETCD_CLIENT_CERT_AUTH: "true"
      ETCD_TRUSTED_CA_FILE: /certs/etcd-cs-ca.pem
      ETCD_CERT_FILE: /certs/etcd-server.pem
      ETCD_KEY_FILE: /certs/etcd-server-key.pem
      ETCD_PEER_CLIENT_CERT_AUTH: "true"
      ETCD_PEER_TRUSTED_CA_FILE: /certs/etcd-peer-ca.pem
      ETCD_PEER_CERT_FILE: /certs/etcd-peer.pem
      ETCD_PEER_KEY_FILE: /certs/etcd-peer-key.pem
EOF

cat >daemons/kube-master.yml <<EOF
version: '2'
services:
  kube-api:
    image: bestmike007/hyperkube:v1.9.1
    container_name: kube-api
    restart: always
    network_mode: host
    volumes:
    - /etc/kubernetes:/etc/kubernetes:ro
    command: "/usr/local/bin/kube-apiserver \
              --apiserver-count=3 \
              --allow_privileged=true \
              --service-cluster-ip-range=${SERVICE_CLUSTER_CIDR} \
              --kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname \
              --admission-control=ServiceAccount,NamespaceLifecycle,LimitRanger,PersistentVolumeLabel,DefaultStorageClass,ResourceQuota,DefaultTolerationSeconds \
              --runtime-config=batch/v2alpha1 \
              --runtime-config=authentication.k8s.io/v1beta1=true \
              --runtime-config=extensions/v1beta1/podsecuritypolicy=true \
              --storage-backend=etcd3 \
              --etcd-servers=${ETCD_SERVERS} \
              --etcd-cafile=/etc/kubernetes/etcd-cs-ca.pem \
              --etcd-certfile=/etc/kubernetes/etcd-client.pem \
              --etcd-keyfile=/etc/kubernetes/etcd-client-key.pem \
              --client-ca-file=/etc/kubernetes/kube-ca.pem \
              --service-account-key-file=/etc/kubernetes/kube-service-account.key \
              --tls-ca-file=/etc/kubernetes/kube-ca.pem \
              --tls-cert-file=/etc/kubernetes/kube-api.pem \
              --tls-private-key-file=/etc/kubernetes/kube-api-key.pem \
              --authorization-mode=RBAC \
              --kubelet-client-certificate=/etc/kubernetes/kubelet-client-certificate.pem \
              --kubelet-client-key=/etc/kubernetes/kubelet-client-certificate-key.pem \
              --v=4"
  kube-controller:
    image: bestmike007/hyperkube:v1.9.1
    container_name: kube-controller
    restart: always
    network_mode: host
    volumes:
    - /etc/kubernetes:/etc/kubernetes:ro
    command: "/usr/local/bin/kube-controller-manager \
              --address=0.0.0.0 \
              --leader-elect=true \
              --kubeconfig=/etc/kubernetes/kubecfg-controller.yml \
              --enable-hostpath-provisioner=false \
              --node-monitor-grace-period=40s \
              --pod-eviction-timeout=5m0s \
              --v=2 \
              --allocate-node-cidrs=true \
              --cluster-cidr=${CLUSTER_CIDR} \
              --service-cluster-ip-range=${SERVICE_CLUSTER_CIDR} \
              --service-account-private-key-file=/etc/kubernetes/kube-service-account.key \
              --root-ca-file=/etc/kubernetes/kube-ca.pem \
              --use-service-account-credentials=true"
  kube-scheduler:
    image: bestmike007/hyperkube:v1.9.1
    container_name: kube-scheduler
    restart: always
    network_mode: host
    volumes:
    - /etc/kubernetes:/etc/kubernetes:ro
    command: "/usr/local/bin/kube-scheduler \
              --leader-elect=true \
              --v=2 \
              --kubeconfig=/etc/kubernetes/kubecfg-scheduler.yml \
              --address=0.0.0.0"
EOF

cat >daemons/kube-node.yml <<EOF
version: '2'
services:
  kubelet:
    image: bestmike007/hyperkube:v1.9.1
    container_name: kubelet
    restart: always
    privileged: true
    pid: host
    network_mode: host
    volumes:
    - /var/log:/var/log
    - /dev:/dev
    - /run:/run
    - /sys:/sys:ro
    - /sys/fs/cgroup:/sys/fs/cgroup:rw
    - /var/run:/var/run:rw
    - /var/lib/docker/:/var/lib/docker:rw
    - /var/lib/kubelet/:/var/lib/kubelet:shared
    - /etc/kubernetes:/etc/kubernetes:ro
    - /etc/cni:/etc/cni:ro
    - /opt/cni/bin:/opt/cni/local/bin:rw
    command: bash -c "cp /opt/cni/bin/* /opt/cni/local/bin && \
              /usr/local/bin/kubelet \
              --v=2 \
              --address=0.0.0.0 \
              --anonymous-auth=false \
              --client-ca-file=/etc/kubernetes/kubelet-ca.pem \
              --cluster-domain=cluster.local \
              --pod-infra-container-image=bestmike007/pause-amd64:3.1 \
              --cgroups-per-qos=True \
              --enforce-node-allocatable= \
              --hostname-override=${CURRENT_NODE} \
              --cluster-dns=${CLUSTER_DNS} \
              --network-plugin=cni \
              --cni-conf-dir=/etc/cni/net.d \
              --cni-bin-dir=/opt/cni/local/bin \
              --resolv-conf=/etc/resolv.conf \
              --allow-privileged=true \
              --cloud-provider= \
              --kubeconfig=/etc/kubernetes/kubecfg-kubelet.yml \
              --require-kubeconfig=True \
              --fail-swap-on=false \
              --eviction-hard='${EVICTION_HARD}'"
  kube-proxy:
    image: bestmike007/hyperkube:v1.9.1
    container_name: kube-proxy
    restart: always
    privileged: true
    network_mode: host
    volumes:
    - /etc/kubernetes:/etc/kubernetes:ro
    command: "/usr/local/bin/kube-proxy \
              --healthz-bind-address=0.0.0.0 \
              --kubeconfig=/etc/kubernetes/kubecfg-proxy.yml \
              --v=2"
EOF
```



```
docker-compose -f ~/daemons/etcd.yml up -d
docker-compose -f ~/daemons/kube-master.yml up -d
docker-compose -f ~/daemons/kube-node.yml up -d
```

## Post-config cluster

```bash
# check etcd cluster health
# etcdctl --ca-file=/certs/etcd-cs-ca.pem --endpoints=https://127.0.0.1:2379 --key-file=/certs/etcd-client-key.pem --cert-file=/certs/etcd-client.pem cluster-health

# use the first master, run the following command after `docker exec -it kubelet sh`
kubectl create clusterrolebinding \
kubelet-node-binding --clusterrole=system:node --user=system:kubelet
# set up weave cni network.
# 注意: 这里的IPALLOC_RANGE与SERVICE_CLUSTER_CIDR相同
kubectl apply -f \
"https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')&env.IPALLOC_RANGE=172.18.64.0/18"
```

## Firewall

```bash
# kube-api
ufw allow 6443/tcp
# etcd
ufw allow 2379/tcp
ufw allow 2380/tcp
# weave
ufw allow proto any from ${NODE1} to any port 6783
ufw allow proto any from ${NODE2} to any port 6783
ufw allow proto any from ${NODE3} to any port 6783
ufw allow proto udp from ${NODE1} to any port 6784
ufw allow proto udp from ${NODE2} to any port 6784
ufw allow proto udp from ${NODE3} to any port 6784
# kubelet
ufw allow proto tcp from ${NODE1} to any port 10250
ufw allow proto tcp from ${NODE2} to any port 10250
ufw allow proto tcp from ${NODE3} to any port 10250

```

# Tear down

```bash
docker-compose -f daemons/kube-master.yml down
docker-compose -f daemons/kube-node.yml down
docker-compose -f daemons/etcd.yml down

docker rm $(docker ps -aq) -f
reboot
rm -rf /var/lib/kubelet /srv/etcd /etc/cni /etc/kubernetes /etc/etcd

```