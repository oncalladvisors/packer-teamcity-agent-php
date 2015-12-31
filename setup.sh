#!/usr/bin/env bash

# much of this is from: https://github.com/sjoerdmulder/teamcity-agent-docker/blob/master/Dockerfile
export AGENT_DIR=/opt/buildAgent

# TEAMCITY_SERVER should be defined in the packer template
#export TEAMCITY_SERVER=teamcity.yoursite.com

apt-get update \
    && apt-get install -y --no-install-recommends \
        lxc aufs-tools ca-certificates curl wget software-properties-common language-pack-en \
        unzip fontconfig libffi-dev build-essential git python-dev libssl-dev python-pip \
        php5-fpm \
        php5-mysql \
        php5-imagick \
        php5-mcrypt \
        php5-curl \
        php5-cli \
        php5-memcache \
        php5-intl \
        php5-gd \
        php5-xdebug \
        php5-gd \
        php5-mongo \
        php5-imap \
        php5-redis \
        php-pear \
        unzip \
        php-apc

# not sure why this is needed... its not if run from docker...
php5enmod mcrypt
php5enmod imap

# Install PHP QA tools and composer
wget https://phar.phpunit.de/phpunit-old.phar
chmod +x phpunit-old.phar
mv phpunit-old.phar /usr/local/bin/phpunit

wget https://phar.phpunit.de/phploc.phar
chmod +x phploc.phar
mv phploc.phar /usr/local/bin/phploc

wget https://squizlabs.github.io/PHP_CodeSniffer/phpcs.phar
chmod +x phpcs.phar
mv phpcs.phar /usr/local/bin/phpcs

wget http://static.pdepend.org/php/latest/pdepend.phar
chmod +x pdepend.phar
mv pdepend.phar /usr/local/bin/pdepend

wget -c http://static.phpmd.org/php/latest/phpmd.phar
chmod +x phpmd.phar
mv phpmd.phar /usr/local/bin/phpmd

wget https://phar.phpunit.de/phpcpd.phar
chmod +x phpcpd.phar
mv phpcpd.phar /usr/local/bin/phpcpd


wget http://phpdox.de/releases/phpdox.phar
chmod +x phpdox.phar
mv phpdox.phar /usr/local/bin/phpdox

curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin
mv /usr/local/bin/composer.phar /usr/local/bin/composer

# Fix locale.
export LANG=en_US.UTF-8
export LC_CTYPE=en_US.UTF-8
locale-gen en_US && update-locale LANG=en_US.UTF-8 LC_CTYPE=en_US.UTF-8


# grab gosu for easy step-down from root
gpg --keyserver ha.pool.sks-keyservers.net --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4
curl -o /usr/local/bin/gosu -SL "https://github.com/tianon/gosu/releases/download/1.6/gosu-$(dpkg --print-architecture)" \
    && curl -o /usr/local/bin/gosu.asc -SL "https://github.com/tianon/gosu/releases/download/1.6/gosu-$(dpkg --print-architecture).asc" \
    && gpg --verify /usr/local/bin/gosu.asc \
    && rm /usr/local/bin/gosu.asc \
    && chmod +x /usr/local/bin/gosu

# Install java-8-oracle
echo debconf shared/accepted-oracle-license-v1-1 select true | debconf-set-selections \
    && echo debconf shared/accepted-oracle-license-v1-1 seen true | debconf-set-selections \
    && add-apt-repository -y ppa:webupd8team/java \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
      oracle-java8-installer ca-certificates-java \
    && ln -s /etc/ssl/certs/java/cacerts /usr/lib/jvm/java-8-oracle/jre/lib/security/cacerts \
    && update-ca-certificates

# Install Docker
apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D
echo "deb https://apt.dockerproject.org/repo ubuntu-trusty main" > /etc/apt/sources.list.d/docker.list
apt-get update \
    && apt-get install -y --no-install-recommends \
    linux-image-extra-$(uname -r) docker-engine
service docker start

# wget -O /usr/local/bin/docker https://get.docker.com/builds/Linux/x86_64/docker-1.9.1 && chmod +x /usr/local/bin/docker

groupadd docker && adduser --disabled-password --gecos "" teamcity \
    && sed -i -e "s/%sudo.*$/%sudo ALL=(ALL:ALL) NOPASSWD:ALL/" /etc/sudoers \
    && usermod -a -G docker,sudo teamcity

# Install jq (from github, repo contains ancient version)
curl -o /usr/local/bin/jq -SL https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64 
chmod +x /usr/local/bin/jq



# Install ruby and node.js build repositories
# apt-add-repository ppa:chris-lea/node.js \
#     && apt-add-repository ppa:brightbox/ruby-ng \
#     && apt-get update \
#     && apt-get upgrade -y \
#     && apt-get install -y nodejs ruby2.1 ruby2.1-dev ruby ruby-switch  \
#     && rm -rf /var/lib/apt/lists/*

# Install httpie (with SNI), awscli, docker-compose
pip install --upgrade pyopenssl pyasn1 ndg-httpsclient httpie awscli docker-compose==1.5.2
# ruby-switch --set ruby2.1
# npm install -g bower grunt-cli
# gem install rake bundler compass --no-ri --no-rdoc



# from entrypoint.sh
if [ -z "$TEAMCITY_SERVER" ]; then
    echo "TEAMCITY_SERVER variable not set, launch with -e TEAMCITY_SERVER=http://mybuildserver"
    exit 1
fi

if [ ! -d "$AGENT_DIR/bin" ]; then
    echo "$AGENT_DIR doesn't exist pulling build-agent from server $TEAMCITY_SERVER";
    let waiting=0
    until curl -s -f -I -X GET $TEAMCITY_SERVER/update/buildAgent.zip; do
        let waiting+=3
        sleep 3
        if [ $waiting -eq 120 ]; then
            echo "Teamcity server did not respond within 120 seconds"...
            exit 42
        fi
    done
    wget $TEAMCITY_SERVER/update/buildAgent.zip && unzip -d $AGENT_DIR buildAgent.zip && rm buildAgent.zip
    chmod +x $AGENT_DIR/bin/agent.sh
    echo "serverUrl=${TEAMCITY_SERVER}" > $AGENT_DIR/conf/buildAgent.properties
    # echo "name=" >> $AGENT_DIR/conf/buildAgent.properties
    # echo "workDir=../work" >> $AGENT_DIR/conf/buildAgent.properties
    # echo "tempDir=../temp" >> $AGENT_DIR/conf/buildAgent.properties
    # echo "systemDir=../system" >> $AGENT_DIR/conf/buildAgent.properties
fi

chown -R teamcity:teamcity /opt/buildAgent

# possibility 3:
cat <<EOT >> /etc/init.d/teamcity
#! /bin/sh
# /etc/init.d/teamcity 
# Carry out specific functions when asked to by the system
case "\$1" in
  start)
    echo "Starting script teamcity "
    $AGENT_DIR/bin/agent.sh start
    ;;
  stop)
    echo "Stopping script teamcity"
    $AGENT_DIR/bin/agent.sh stop
    ;;
  *)
    echo "Usage: /etc/init.d/teamcity {start|stop}"
    exit 1
    ;;
esac

exit 0
EOT

sudo chmod +x /etc/init.d/teamcity
update-rc.d teamcity defaults
