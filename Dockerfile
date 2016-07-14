FROM mhart/alpine-node

ADD assets/ /opt/resource/
RUN chmod +x /opt/resource/*

ADD fly-linux-1.4.1 /usr/local/bin/fly
RUN chmod +x /usr/local/bin/fly

ADD spruce-linux-1.5.0 /usr/local/bin/spruce
RUN chmod +x /usr/local/bin/spruce

RUN apk update && \
    apk add git && \
    npm install -y -g json2yaml