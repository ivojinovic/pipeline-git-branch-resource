FROM concourse/buildroot:git

ADD assets/ /opt/resource/
ADD ci/project_pipeline/build.sh /opt/resource/build.sh
ADD ci/project_pipeline/pipeline_start.yaml /opt/resource/pipeline_start.yaml
ADD ci/project_pipeline/pipeline_resources.yaml /opt/resource/pipeline_resources.yaml
ADD ci/project_pipeline/pipeline_jobs.yaml /opt/resource/pipeline_jobs.yaml
RUN chmod +x /opt/resource/*

ADD fly-lynux-1.3.1 /usr/local/bin/fly
RUN chmod +x /usr/local/bin/fly

ADD spruce-linux-1.5.0 /usr/local/bin/spruce
RUN chmod +x /usr/local/bin/spruce

ADD scripts/install_git_lfs.sh install_git_lfs.sh
RUN ./install_git_lfs.sh
