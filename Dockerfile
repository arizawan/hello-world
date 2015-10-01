FROM ubuntu:14.04
MAINTAINER Ahmed Rizawan <ahm.rizawan@gmail.com>

# Let the conatiner know that there is no tty
ENV DEBIAN_FRONTEND noninteractive

# User Configs
ENV REPOHOST=bitbucket.org
ENV NODE_VERSION=0.12.7
ENV NPM_VERSION=2.14.1
ENV APPGITURL=git@bitbucket.org:parkiee/frontend-web.git
ENV APPGITBRUNCH=develop
ENV APPROOTDIR=/srv/www
ENV APPTYPE=master

# verify gpg and sha256: http://nodejs.org/dist/v0.10.30/SHASUMS256.txt.asc
# gpg: aka "Timothy J Fontaine (Work) <tj.fontaine@joyent.com>"
# gpg: aka "Julien Gilli <jgilli@fastmail.fm>"
RUN set -ex \
	&& for key in \
		7937DFD2AB06298B2293C3187D33FF9D0246406D \
		114F43EE0176B71C7BC219DD50A3051F888C628D \
	; do \
		gpg --keyserver ha.pool.sks-keyservers.net --recv-keys "$key"; \
	done

# SSH config & others
ADD configs /configs
RUN apt-get -y install openssh-server python-setuptools && \
	mkdir -p /configs/ssh && \
    mkdir /root/.ssh && \
    mkdir -p /var/log/supervisor && \
    mv /configs/ssh/* /root/.ssh/ && \
    cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys && \
    chmod 600 /root/.ssh/authorized_keys && \
    chmod 400 /root/.ssh/id_rsa && \
    ssh-keyscan -H $REPOHOST >> ~/.ssh/known_hosts

# Install Nodejs and Modules
RUN apt-get install curl -y && \
	curl -SLO "https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-linux-x64.tar.gz" \
	&& curl -SLO "https://nodejs.org/dist/v$NODE_VERSION/SHASUMS256.txt.asc" \
	&& gpg --verify SHASUMS256.txt.asc \
	&& grep " node-v$NODE_VERSION-linux-x64.tar.gz\$" SHASUMS256.txt.asc | sha256sum -c - \
	&& tar -xzf "node-v$NODE_VERSION-linux-x64.tar.gz" -C /usr/local --strip-components=1 \
	&& rm "node-v$NODE_VERSION-linux-x64.tar.gz" SHASUMS256.txt.asc \
	&& npm install -g npm@"$NPM_VERSION" \
	&& npm cache clear \
	&& npm -g install gulp bower

# Install Git
RUN apt-get install -y curl git unzip wget vim

# Install Application
RUN rm -rf $APPROOTDIR && \
	mkdir -p $APPROOTDIR && \
    echo 'Installing Application...' && \
    ssh-keyscan -H $REPOHOST >> ~/.ssh/known_hosts && \
    git clone $APPGITURL $APPROOTDIR

# Setup Application
WORKDIR $APPROOTDIR
RUN npm install && bower install --allow-root && \
	gulp build

# Install Nginx
RUN apt-get install -y software-properties-common && \
	add-apt-repository ppa:nginx/stable && \
    apt-get update && \
    apt-get -y install nginx


# Supervisor
RUN /usr/bin/easy_install supervisor && \
    /usr/bin/easy_install supervisor-stdout && \
    mv /configs/supervisord.conf /etc/supervisord.conf && \
    rm -rf /etc/nginx/sites-available/* && \
    mv /configs/nginx-site.conf /etc/nginx/sites-available/default

# App Initialization and Startup Script
ADD ./start.sh /main_init.sh
RUN chmod 755 /main_init.sh

# Clean up APT & Configs when done.
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /configs

# Tell Docker we are going to use this port
EXPOSE 80
EXPOSE 3000

# The command to run our app when the container is run
CMD ["/bin/bash", "/main_init.sh"]

