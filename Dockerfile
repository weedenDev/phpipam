FROM php:5.6-apache
MAINTAINER Shea Stewart <shea.stewart@arctiq.ca>


ENV PHPIPAM_SOURCE https://github.com/phpipam/phpipam/archive/
ENV PHPIPAM_VERSION 1.3
ENV WEB_REPO /var/www/html
ENV PATH=${WEB_REPO}/bin:${PATH} HOME=${WEB_REPO}

# Install required deb packages
RUN apt-get update && apt-get -y upgrade && \
    apt-get install -y libgmp-dev libmcrypt-dev libfreetype6-dev libjpeg-dev libpng-dev libldap2-dev && \
    rm -rf /var/lib/apt/lists/*

# OpenShift permission modifications
RUN mkdir -p /var/run/apache2 && chmod 777 -R /var/run/apache2 &&\
    mkdir -p /var/log/apache2 && chmod 777 -R /var/log/apache2 &&\
    mkdir -p /var/lock/apache2 && chmod 777 -R /var/lock/apache2 &&\
    mkdir -p /etc/apache2/sites-enabled && chmod 777 -R /etc/apache2/sites-enabled &&\
    mkdir -p /var/www/html && chmod 777 -R /var/www/html && \
    chmod 664 /etc/passwd


# Configure apache and required PHP modules
RUN docker-php-ext-configure mysqli --with-mysqli=mysqlnd && \
    docker-php-ext-install mysqli && \
    docker-php-ext-configure gd --enable-gd-native-ttf --with-freetype-dir=/usr/include/freetype2 --with-png-dir=/usr/include --with-jpeg-dir=/usr/include && \
    docker-php-ext-install gd && \
    docker-php-ext-install sockets && \
    docker-php-ext-install pdo_mysql && \
    docker-php-ext-install gettext && \
    ln -s /usr/include/x86_64-linux-gnu/gmp.h /usr/include/gmp.h && \
    docker-php-ext-configure gmp --with-gmp=/usr/include/x86_64-linux-gnu && \
    docker-php-ext-install gmp && \
    docker-php-ext-install mcrypt && \
    docker-php-ext-install pcntl && \
    docker-php-ext-configure ldap --with-libdir=lib/x86_64-linux-gnu && \
    docker-php-ext-install ldap && \
    echo ". /etc/environment" >> /etc/apache2/envvars && \
    a2enmod rewrite

COPY php.ini /usr/local/etc/php/

# copy phpipam sources to web dir
ADD ${PHPIPAM_SOURCE}/${PHPIPAM_VERSION}.tar.gz /tmp/
RUN tar -xzf /tmp/${PHPIPAM_VERSION}.tar.gz -C ${WEB_REPO}/ --strip-components=1


RUN cp ${WEB_REPO}/config.dist.php ${WEB_REPO}/config.php && \
    sed -i -e "s/Listen 80/Listen 8080/" /etc/apache2/ports.conf &&\
    sed -i -e "s/\['host'\] = 'localhost'/\['host'\] = 'mysql'/" \
    -e "s/\['user'\] = 'phpipam'/\['user'\] = 'root'/" \
    -e "s/\['pass'\] = 'phpipamadmin'/\['pass'\] = getenv(\"MYSQL_ENV_MYSQL_ROOT_PASSWORD\")/" \
    ${WEB_REPO}/config.php && \
    sed -i -e "s/\['port'\] = 3306;/\['port'\] = 3306;\n\n\$password_file = getenv(\"MYSQL_ENV_MYSQL_ROOT_PASSWORD\");\nif(file_exists(\$password_file))\n\$db\['pass'\] = preg_replace(\"\/\\\\s+\/\", \"\", file_get_contents(\$password_file));/" \
    ${WEB_REPO}/config.php

USER 10001

WORKDIR ${WEB_REPO}

EXPOSE 8080
