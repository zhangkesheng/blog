---
title: Let's Encrypt 实现站点 SSL
date: 2018-04-16 16:45:28
tags: 
  - SSL
  - HTTPS
categories: 笔记
---

# Let's Encrypt 实现站点 SSL

本文介绍如何使用[Let's Encrypt](https://letsencrypt.org/)实现网站的https访问

> 引用了下列网站的内容:
>
> [免费 SSL：Ubuntu 16.04 配置 Let's Encrypt 实现站点 SSL](https://mp.weixin.qq.com/s?__biz=MzI5MDcyODM1OA==&mid=2247483846&idx=1&sn=7d26ae40ff50c4ec4d0d9a20a36e5275&chksm=ec1a310fdb6db819847d76043868c5796643cc1bc8eb2c623227d6eb297fb74d9b2a7d9f5ef7#rd)
>
> [[使用Let's Encrypt加密你的小站](http://www.cnblogs.com/SzeCheng/p/8075799.html)]

## 介绍

[Let's Encrypt](https://letsencrypt.org/)是一个免费并且开源的CA, 且已经获得Mozilla, 微软等主要浏览器厂商的根授信. 它极大低降低DV证书的入门门槛, 进而推进全网的HTTPS化.

## 安装

安装Let's Encrypt的自动部署脚本: Certbot.

```bash
# 安装nginx, 若已安装, 可跳过
apt-get install nginx
# 添加certbot的package repository
add-apt-repository ppa:certbot/certbot
# 提示 Press [ENTER] to continue or ctrl-c to cancel adding it, 直接Enter即可
# 更新数据源
apt-get update
# 安装 certbot, 若机器上已有python和nginx, 可以只安装certbot. `apt-get install certbot`
apt-get install python-certbot-nginx
```

## 签发SSL证书

使用certbot签发证书

```bash
certbot certonly --standalone --email your@email.com -d yourdomain.com -d test.yourdomain.com
```

证书会生成在`/etc/letsencrypt/live/yourdomain`下, 如有需要, 可自行copy到其他文件夹.

## 配置nginx

在nginx目录下创建ssl-test.conf, 内容如下:

```bash
server {
    # SSL configuration

    listen 443 ssl;
    listen [::]:443 ssl;
    ssl on;

    ssl_certificate   /etc/letsencrypt/live/yourdomain.com/fullchain.pem;
    ssl_certificate_key  /etc/letsencrypt/live/yourdomain.com/privkey.pem;
    ssl_session_timeout 5m;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE:ECDH:AES:HIGH:!NULL:!aNULL:!MD5:!ADH:!RC4;
    ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
    ssl_prefer_server_ciphers on;

    root /var/www/html;

        # Add index.php to the list if you are using PHP
        index index.html index.htm index.nginx-debian.html;

        location / {
                # First attempt to serve request as file, then
                # as directory, then fall back to displaying a 404.
                proxy_set_header X-Real-IP $remote_addr;
                proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                proxy_set_header Host $http_host;
                try_files $uri $uri/ =404;
        }
}
```

重新启动nginx服务

```ba
nginx -t && nginx -s reload
```

这时候在域名前加https就可以访问了.

## 添加https访问

在nginx文件夹下新建一个ssl.conf, 统一配置, 暂时没有用

```ba
ssl on;
ssl_session_cache shared:SSL:10m;
ssl_session_timeout 24h;
ssl_buffer_size 1400;
ssl_session_tickets off;

ssl_protocols TLSv1 TLSv1.1 TLSv1.2;

ssl_ciphers AES256+EECDH:AES256+EDH:!aNULL;
# ssl_ciphers "EECDH+AESGCM:EDH+AESGCM:ECDHE-RSA-AES128-GCM-SHA256:AES256+EECDH:DHE-RSA-AES128-GCM-SHA256:AES256+EDH:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-RSA-AES128-SHA256:ECDHE-RSA-AES256-SHA:ECDHE-RSA-AES128-SHA:DHE-RSA-AES256-SHA256:DHE-RSA-AES128-SHA256:DHE-RSA-AES256-SHA:DHE-RSA-AES128-SHA:ECDHE-RSA-DES-CBC3-SHA:EDH-RSA-DES-CBC3-SHA:AES256-GCM-SHA384:AES128-GCM-SHA256:AES256-SHA256:AES128-SHA256:AES256-SHA:AES128-SHA:DES-CBC3-SHA:HIGH:!aNULL:!eNULL:!EXPORT:!DES:!MD5:!PSK:!RC4";
ssl_prefer_server_ciphers on;

ssl_certificate   /etc/letsencrypt/live/yourdomain.com/fullchain.pem;
ssl_certificate_key  /etc/letsencrypt/live/yourdomain.com/privkey.pem;

#ssl_stapling on;
#ssl_stapling_verify on;
#resolver 119.29.29.29 223.5.5.5 223.6.6.6 valid=600s;
#resolver_timeout 30s;

#spdy_keepalive_timeout 300;
#spdy_headers_comp 9;

#add_header Strict-Transport-Security max-age=63072000;
#add_header Strict-Transport-Security "max-age=31536000; includeSubdomains" always;
add_header X-Frame-Options DENY;
add_header X-Content-Type-Options nosniff;

```

创建一个conf

```bash
server {
  listen 443 ssl;
  server_name test.yourdomain.com;
  ssl on;
  ssl_certificate   /etc/letsencrypt/live/xiaoshaniu.xin/fullchain.pem;
  ssl_certificate_key  /etc/letsencrypt/live/xiaoshaniu.xin/privkey.pem;

  client_max_body_size 1G;
  proxy_set_header        Host            $host;
  proxy_set_header        X-Real-IP       $remote_addr;
  proxy_set_header        X-Forwarded-For $proxy_add_x_forwarded_for;
  location / {
    proxy_pass http://ip:port;
  }
}
```

仅限https访问, 可以不加

```bash
server {
    listen 80;

    server_name test.yourdomain.com;
    rewrite ^(.*) https://$server_name$1 permanent;
}
```

记得nginx reload

```ba
nginx -t && nginx -s reload
```

至此, 就可以https加密就完成了

## 自动更新证书

因为Let's Encrypt签发的SSL证书有效期只有90天, 所以我们需要在90天内更新证书.

Let's Encrypt也将自动更新的脚本添加到了`/etc/cron.d`里, 只需要执行下面的命令验证一下就可以了.

```bash
certbot renew --dry-run
```

