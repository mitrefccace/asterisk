# When running this Dockerfile, you must specify the HTTP_PROXY
# variable at build time, like so:
# 	$ docker build -t asterisk . --build-arg http_proxy=http://proxy-hostname:port
# Note: HTTP_PROXY is a default ARG variable for Dockerfiles. If you're not using
# one of the defaults, you need to add an ARG directive somewhere near the
# top of the Dockerfile. More info: 
# 	- https://docs.docker.com/engine/reference/builder/#arg
# 	- https://docs.docker.com/engine/reference/builder/#predefined-args
# If you're not behind a proxy, you may need to comment out the
# RUN directive for ~/.wgetrc; otherwise, the wget commands in
# the various bash scripts may fail.

FROM centos:7
WORKDIR /root

# Move the repo code to the container
COPY . asterisk-ad/
WORKDIR asterisk-ad/scripts/

# Set the proxy for yum and git. We specifically need to
# run git config because build_pjproject runs a 'git clone'
# to pull down the asterisk third-party package. (don't know why we need
# to set git config, should pick up http_proxy envt var.........)
RUN export https_proxy="$http_proxy" &&  echo "proxy=$http_proxy" >> /etc/yum.conf

# Some corporate proxies don't play well with the CentOS mirrors,
# so we'll use the base URL instead
RUN sed -i -e 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-Base.repo && \
        sed -i -e 's/#baseurl/baseurl/g' /etc/yum.repos.d/CentOS-Base.repo && \
        sed -i -e 's/gpgcheck=1/gpgcheck=0/g' /etc/yum.conf

RUN yum install -y git mysql && git config --global http.proxy "$http_proxy"

# need to set the #TERM var for the script log messages
# tty chosen to eliminate color output in logs
RUN export TERM=tty
	
# Run the install script
RUN ./AD_asterisk_install.sh --docker-mode 2>&1 | tee build.log

# Run asterisk in the foreground
ENTRYPOINT ["/root/asterisk-ad/scripts/docker-entrypoint.sh"]
EXPOSE 5060 5038
