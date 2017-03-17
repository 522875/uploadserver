FROM openresty/openresty:alpine

RUN apk add --no-cache libuuid &&\
        ln -s /lib/libuuid.so.1 /usr/lib/libuuid.so.1
RUN mkdir -p /data/uploadserver/upload && mkdir -p /data/uploadserver/lib
RUN chown -R nobody:nobody /data/uploadserver/upload
COPY libs /data/uploadserver/libs
COPY uploadfile.lua /data/uploadserver/
COPY conf/nginx.conf /usr/local/openresty/nginx/conf/nginx.conf

