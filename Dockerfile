FROM concourse/buildroot:git

ADD assets/ /opt/resource/
RUN chmod +x /opt/resource/*

ADD fly-linux-1.4.1 /usr/local/bin/fly
RUN chmod +x /usr/local/bin/fly

ADD spruce-linux-1.5.0 /usr/local/bin/spruce
RUN chmod +x /usr/local/bin/spruce

ADD scripts/install_git_lfs.sh install_git_lfs.sh
RUN ./install_git_lfs.sh
