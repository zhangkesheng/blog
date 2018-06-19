FROM node:10.4-alpine as build
MAINTAINER Zhang KeSheng<zks2yuanmin@gmail.com>

COPY . /srv
RUN npm install -g hexo &&\
	cd /srv && npm install && hexo g

FROM nginx:stable-alpine
COPY --from=build /srv/public/ /usr/share/nginx/html/