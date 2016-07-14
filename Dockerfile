FROM docker.zipcar.io/base

ADD assets/ /opt/resource/
RUN chmod +x /opt/resource/*

ADD fly-linux-1.4.1 /usr/local/bin/fly
RUN chmod +x /usr/local/bin/fly

ADD spruce-linux-1.5.0 /usr/local/bin/spruce
RUN chmod +x /usr/local/bin/spruce

RUN apt-get update
RUN apt-get install -y curl libfontconfig autoconf automake build-essential python-dev
RUN curl -sL https://deb.nodesource.com/setup_5.x | sudo -E bash -
RUN apt-get install -y nodejs libfontconfig autoconf automake build-essential python-dev git && \
    npm install -y -g json2yaml