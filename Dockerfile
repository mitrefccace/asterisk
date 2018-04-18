# When running this Dockerfile, you must specify the HTTP_PROXY
# variable at build time, like so:
# 	$ docker build -t asterisk . --build-arg http_proxy=http://gatekeeper-w.mitre.org:80
# Note: HTTP_PROXY is a default ARG variable for Dockerfiles. If you're not using
# one of the defaults, you need to add an ARG directive somewhere near the
# top of the Dockerfile. More info: 
# 	- https://docs.docker.com/engine/reference/builder/#arg
# 	- https://docs.docker.com/engine/reference/builder/#predefined-args
# If you're not behind a proxy, you may need to comment out the
# RUN directive for ~/.wgetrc; otherwise, the wget commands in
# the various bash scripts may fail.


FROM centos:latest
WORKDIR /root

# Move the repo code to the container
COPY . asterisk-ad/
WORKDIR asterisk-ad/scripts/

# Set the proxy for yum and git. We specifically need to
# run git config because build_pjproject runs a 'git clone'
# to pull down the asterisk third-party package. (don't know why we need
# to set git config, should pick up http_proxy envt var.........)
RUN export https_proxy=$http_proxy &&  echo "proxy=$http_proxy" >> /etc/yum.conf
# The MITRE & ECE proxies don't play well with the CentOS mirrors,
# so we'll use the base URL instead
RUN sed -i -e 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-Base.repo && \
        sed -i -e 's/#baseurl/baseurl/g' /etc/yum.repos.d/CentOS-Base.repo && \
        sed -i -e 's/gpgcheck=1/gpgcheck=0/g' /etc/yum.conf

RUN yum install -y git && git config --global http.proxy $http_proxy

# If we're in CI_MODE, prepare .config. Otherwise, this will be handled in
# docker-entrypoint.sh
RUN if [ -n CI_MODE ]; then export IP_ADDR=$(hostname -I | awk "{print $1}") && \
	sed -i -e "s/HOSTNAME/jenkins.task3acrdemo.com/g" .config.sample && \
        sed -i -e "s/192.168.0.1/$IP_ADDR/g" .config.sample && \
        sed -i -e "s/8.8.8.8/$IP_ADDR/g" .config.sample && \
        sed -i -e "s/stun.example.com/stun.task3acrdemo.com/g" .config.sample && \
        sed -i -e "s/db_hostname/ace-direct-mysql.ceq7afndeyku.us-east-1.rds.amazonaws.com/g" .config.sample && \
        sed -i -e "s/database/asterisk/g" .config.sample && \
        sed -i -e "s/table/vasip/g" .config.sample && \
        sed -i -e "s/somePass/2tZTp&b49#TSFYc2/g" .config.sample && \
        mv .config.sample .config ; fi

# need to set the #TERM var for the script log messages
RUN export $TERM=xterm
	
# Run the install script
RUN ./AD_asterisk_install.sh --docker-mode

# Run asterisk in the foreground
ENTRYPOINT ["/root/asterisk-ad/scripts/docker-entrypoint.sh"]
#CMD asterisk && sleep 5 && /root/asterisk-codev/scripts/docker-entrypoint.sh && asterisk -r
