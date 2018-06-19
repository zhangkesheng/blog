---
title: Kubernetes Install
date: 2017-11-16 11:12:16
tags: 笔记
categories: Kubernetes
---
# 安装 Kubernetes

## 准备工作

1. 科学上网
2. 关闭swap, `swapoff -a` 重启之后又会打开, 所以可以直接修改'/etc/fstab'.

## Installing Docker

K8s(即'Kebunetes') 1.8版本, 官方网站要安装说明安装了docker17.03, 若是docker版本过高, 也会有docker版本过高的提示, 所以这里就按照官网要求, 安装docker 17.03.

~~~shell
apt-get update && apt-get install -y curl apt-transport-https
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
cat <<EOF >/etc/apt/sources.list.d/docker.list
deb https://download.docker.com/linux/$(lsb_release -si | tr '[:upper:]' '[:lower:]') $(lsb_release -cs) stable
EOF
apt-get update && apt-get install -y docker-ce=$(apt-cache madison docker-ce | grep 17.03 | head -1 | awk '{print $3}')
~~~



## Installing Kubeadm

Kubernetes and docker 需要科学上网, 所以需要设置代理.

docker代理, kubeadm init时需要下载镜像, 所以需要设置docker的代理

/etc/systemd/system/docker.service.d/http-proxy.conf 

~~~shell
[Service]
Environment="HTTP_PROXY=http://192.168.32.10:6780"
Environment="HTTPS_PROXY=http://192.168.32.10:6780"
Environment="NO_PROXY=.aliyun.com,.aliyuncs.com,.daocloud.io,.cn,localhost"
~~~

> note: no_proxy不支持通配符

命令行代理

~~~shell
export http_proxy=http://host:port
export https_proxy=http://host:port
export NO_PROXY=.aliyun.com,.aliyuncs.com,.daocloud.io,.cn,localhost,自己的IP #设置no_proxy, 说明见下面
~~~

install kubeadm

~~~shell
apt-get update && apt-get install -y apt-transport-https
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb http://apt.kubernetes.io/ kubernetes-xenial main
EOF
apt-get update
apt-get install -y kubelet kubeadm kubectl
~~~



## Kueadm Init

如果没有设置命令行no_proxy, 直接执行, 会结果如下:

~~~shell
[kubeadm] WARNING: kubeadm is in beta, please do not use it for production clusters.
[init] Using Kubernetes version: v1.8.3
[init] Using Authorization modes: [Node RBAC]
[preflight] Running pre-flight checks
[preflight] WARNING: Connection to "https://192.168.10.57:6443" uses proxy "http://192.168.32.10:6780". If that is not intended, adjust your proxy settings
[preflight] WARNING: Running with swap on is not supported. Please disable swap or set kubelet's --fail-swap-on flag to false.
[kubeadm] WARNING: starting in 1.8, tokens expire after 24 hours by default (if you require a non-expiring token use --token-ttl 0)
[certificates] Generated ca certificate and key.
[certificates] Generated apiserver certificate and key.
[certificates] apiserver serving cert is signed for DNS names [docker-host kubernetes kubernetes.default kubernetes.default.svc kubernetes.default.svc.cluster.local] and IPs [10.96.0.1 192.168.10.57]
[certificates] Generated apiserver-kubelet-client certificate and key.
[certificates] Generated sa key and public key.
[certificates] Generated front-proxy-ca certificate and key.
[certificates] Generated front-proxy-client certificate and key.
[certificates] Valid certificates and keys now exist in "/etc/kubernetes/pki"
[kubeconfig] Wrote KubeConfig file to disk: "admin.conf"
[kubeconfig] Wrote KubeConfig file to disk: "kubelet.conf"
[kubeconfig] Wrote KubeConfig file to disk: "controller-manager.conf"
[kubeconfig] Wrote KubeConfig file to disk: "scheduler.conf"
[controlplane] Wrote Static Pod manifest for component kube-apiserver to "/etc/kubernetes/manifests/kube-apiserver.yaml"
[controlplane] Wrote Static Pod manifest for component kube-controller-manager to "/etc/kubernetes/manifests/kube-controller-manager.yaml"
[controlplane] Wrote Static Pod manifest for component kube-scheduler to "/etc/kubernetes/manifests/kube-scheduler.yaml"
[etcd] Wrote Static Pod manifest for a local etcd instance to "/etc/kubernetes/manifests/etcd.yaml"
[init] Waiting for the kubelet to boot up the control plane as Static Pods from directory "/etc/kubernetes/manifests"
[init] This often takes around a minute; or longer if the control plane images have to be pulled. #时间会很长, 要等一会
[kubelet-check] It seems like the kubelet isn't running or healthy.
[kubelet-check] The HTTP call equal to 'curl -sSL http://localhost:10255/healthz' failed with error: Get http://localhost:10255/healthz: dial tcp [::1]:10255: getsockopt: connection refused.
[kubelet-check] It seems like the kubelet isn't running or healthy.
[kubelet-check] The HTTP call equal to 'curl -sSL http://localhost:10255/healthz' failed with error: Get http://localhost:10255/healthz: dial tcp [::1]:10255: getsockopt: connection refused.
[kubelet-check] It seems like the kubelet isn't running or healthy.
[kubelet-check] The HTTP call equal to 'curl -sSL http://localhost:10255/healthz' failed with error: Get http://localhost:10255/healthz: dial tcp [::1]:10255: getsockopt: connection refused.
[kubelet-check] It seems like the kubelet isn't running or healthy.
[kubelet-check] The HTTP call equal to 'curl -sSL http://localhost:10255/healthz/syncloop' failed with error: Get http://localhost:10255/healthz/syncloop: dial tcp [::1]:10255: getsockopt: connection refused.
[kubelet-check] It seems like the kubelet isn't running or healthy.
[kubelet-check] The HTTP call equal to 'curl -sSL http://localhost:10255/healthz/syncloop' failed with error: Get http://localhost:10255/healthz/syncloop: dial tcp [::1]:10255: getsockopt: connection refused.
[kubelet-check] It seems like the kubelet isn't running or healthy.
[kubelet-check] The HTTP call equal to 'curl -sSL http://localhost:10255/healthz/syncloop' failed with error: Get http://localhost:10255/healthz/syncloop: dial tcp [::1]:10255: getsockopt: connection refused.
[kubelet-check] It seems like the kubelet isn't running or healthy.
[kubelet-check] The HTTP call equal to 'curl -sSL http://localhost:10255/healthz' failed with error: Get http://localhost:10255/healthz: dial tcp [::1]:10255: getsockopt: connection refused.
[kubelet-check] It seems like the kubelet isn't running or healthy.
[kubelet-check] The HTTP call equal to 'curl -sSL http://localhost:10255/healthz/syncloop' failed with error: Get http://localhost:10255/healthz/syncloop: dial tcp [::1]:10255: getsockopt: connection refused.
[kubelet-check] It seems like the kubelet isn't running or healthy.
[kubelet-check] The HTTP call equal to 'curl -sSL http://localhost:10255/healthz' failed with error: Get http://localhost:10255/healthz: dial tcp [::1]:10255: getsockopt: connection refused.

Unfortunately, an error has occurred:
	timed out waiting for the condition

This error is likely caused by that:
	- The kubelet is not running
	- The kubelet is unhealthy due to a misconfiguration of the node in some way (required cgroups disabled)
	- There is no internet connection; so the kubelet can't pull the following control plane images:
		- gcr.io/google_containers/kube-apiserver-amd64:v1.8.3
		- gcr.io/google_containers/kube-controller-manager-amd64:v1.8.3
		- gcr.io/google_containers/kube-scheduler-amd64:v1.8.3

You can troubleshoot this for example with the following commands if you're on a systemd-powered system:
	- 'systemctl status kubelet'
	- 'journalctl -xeu kubelet'
couldn't initialize a Kubernetes cluster

~~~

这里需要设置命令行的no_proxy, 也可以在设置代理的时候

~~~shell
export NO_PROXY=.aliyun.com,.aliyuncs.com,.daocloud.io,.cn,localhost,自己的IP #设置no_proxy
~~~

> NOTE: 如果init的时间很长, 并且docker并没有什么反应, 可以重新删除k8s, 重新install再init.
>
> kubeadm init 没有使用代理则不会成功, 被坑惨了. 之后重新install才解决问题.
>
> 只了解了问题的表象, 需要去分析问题发生的原因.

成功结果如下:

~~~shel
[kubeadm] WARNING: kubeadm is in beta, please do not use it for production clusters.
[init] Using Kubernetes version: v1.8.3
[init] Using Authorization modes: [Node RBAC]
[preflight] Running pre-flight checks
[kubeadm] WARNING: starting in 1.8, tokens expire after 24 hours by default (if you require a non-expiring token use --token-ttl 0)
[certificates] Generated ca certificate and key.
[certificates] Generated apiserver certificate and key.
[certificates] apiserver serving cert is signed for DNS names [docker-host kubernetes kubernetes.default kubernetes.default.svc kubernetes.default.svc.cluster.local] and IPs [10.96.0.1 192.168.10.57]
[certificates] Generated apiserver-kubelet-client certificate and key.
[certificates] Generated sa key and public key.
[certificates] Generated front-proxy-ca certificate and key.
[certificates] Generated front-proxy-client certificate and key.
[certificates] Valid certificates and keys now exist in "/etc/kubernetes/pki"
[kubeconfig] Wrote KubeConfig file to disk: "admin.conf"
[kubeconfig] Wrote KubeConfig file to disk: "kubelet.conf"
[kubeconfig] Wrote KubeConfig file to disk: "controller-manager.conf"
[kubeconfig] Wrote KubeConfig file to disk: "scheduler.conf"
[controlplane] Wrote Static Pod manifest for component kube-apiserver to "/etc/kubernetes/manifests/kube-apiserver.yaml"
[controlplane] Wrote Static Pod manifest for component kube-controller-manager to "/etc/kubernetes/manifests/kube-controller-manager.yaml"
[controlplane] Wrote Static Pod manifest for component kube-scheduler to "/etc/kubernetes/manifests/kube-scheduler.yaml"
[etcd] Wrote Static Pod manifest for a local etcd instance to "/etc/kubernetes/manifests/etcd.yaml"
[init] Waiting for the kubelet to boot up the control plane as Static Pods from directory "/etc/kubernetes/manifests"
[init] This often takes around a minute; or longer if the control plane images have to be pulled.
[apiclient] All control plane components are healthy after 156.501511 seconds
[uploadconfig] Storing the configuration used in ConfigMap "kubeadm-config" in the "kube-system" Namespace
[markmaster] Will mark node docker-host as master by adding a label and a taint
[markmaster] Master docker-host tainted and labelled with key/value: node-role.kubernetes.io/master=""
[bootstraptoken] Using token: ce5ad4.07b7b63c25b711b0
[bootstraptoken] Configured RBAC rules to allow Node Bootstrap tokens to post CSRs in order for nodes to get long term certificate credentials
[bootstraptoken] Configured RBAC rules to allow the csrapprover controller automatically approve CSRs from a Node Bootstrap Token
[bootstraptoken] Configured RBAC rules to allow certificate rotation for all node client certificates in the cluster
[bootstraptoken] Creating the "cluster-info" ConfigMap in the "kube-public" namespace
[addons] Applied essential addon: kube-dns
[addons] Applied essential addon: kube-proxy

Your Kubernetes master has initialized successfully!

To start using your cluster, you need to run (as a regular user):

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

You should now deploy a pod network to the cluster.
Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
  http://kubernetes.io/docs/admin/addons/

You can now join any number of machines by running the following on each node
as root:

  kubeadm join --token ce5ad4.07b7b63c25b711b0 192.168.10.57:6443 --discovery-token-ca-cert-hash sha256:da4ea96d2fdb7c3936d0870534688926e6c47738eca6c1d3b74283bf4ec0f171
~~~

docker ps 查看k8s运行情况

![img](http://ogazogo04.bkt.clouddn.com/1510726943%281%29.jpg)

为让Pod直接可以相互通信, 需要安装网络插件, k8s支持很多种网络, 包括Weave, Calico, Flannel等, 详情见https://kubernetes.io/docs/setup/independent/create-cluster-kubeadm/.

我们选择了Weave Net, 安装命令

~~~shell
kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')"
~~~

kubernetes配置

```shell
echo "export KUBECONFIG=/etc/kubernetes/admin.conf" >> ~/.bashrc
```

之后就可以执行`kubectl get nodes` 查看node

![1510727212(1)](http://ogazogo04.bkt.clouddn.com/1510727212%281%29.jpg)

如果status是NotReady, 需要等一下, docker container全部运行成功后status就会变成Ready.

## Kebernetes Dashboard

安装k8s dashboard github 地址 [kubernetes/dashboard](https://github.com/kubernetes/dashboard) 

~~~shell
git clone https://github.com/kubernetes/heapster.git
kubectl create -f deploy/kube-config/influxdb/
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/master/src/deploy/recommended/kubernetes-dashboard.yaml
~~~

然后执行`kubectl -n kube-system edit service kubernetes-dashboard` 将**spec.type**改为**NodePort**, 添加**spec.porte.nodePort**=**31700**, 31700为访问dashboard的IP.

之后浏览器访问https://<master-ip>:31700就可以查看dashboard.

测试环境skip跳过登录就可以查看, 会有权限问题.

添加一个dashboard-admin.yaml文件, 内容如下:

~~~shell
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: kubernetes-dashboard
  labels:
    k8s-app: kubernetes-dashboard
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: kubernetes-dashboard
  namespace: kube-system
~~~

执行`kubectl create -f dashboard-admin.yaml`就可以不用登录查看dashboard.

> NOTE: 测试时可以这样, 线上千万不要这样做!

到此, 就安装好了k8s, 并且添加了dashboard查看相关的内容. 

k8s更多的内容就要各位自己去发现了.

未完待续...