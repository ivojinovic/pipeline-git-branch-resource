FROM concourse/buildroot:git

ADD assets/ /opt/resource/
ADD ci/project_pipeline/ /opt/resource/
ADD ci/project_pipeline.yaml /opt/resource/project_pipeline.yaml
RUN chmod +x /opt/resource/*

ADD fly-lynux-1.3.1 /usr/local/bin/fly
RUN chmod +x /usr/local/bin/fly

ADD spruce-linux-1.5.0 /usr/local/bin/spruce
RUN chmod +x /usr/local/bin/spruce

ADD scripts/install_git_lfs.sh install_git_lfs.sh
RUN ./install_git_lfs.sh
