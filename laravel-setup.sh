#!/usr/bin/env bash
############################################################
#Script Name: automation script larval project
#author: Lakmal-ya
############################################################
#Domain name user input
read -p "Enter domain name : " domain
#mysql endpoint name user input
read -p "Enter git URL : " URL
#Project name user input
read -p "Enter project name : " project
#mysql endpoint name user input
read -p "Enter mysql endpoint name : " mysql_endpoint
#mysql endpoint name user input
read -p "Enter mysql root password : " mysql_root_pw

# Functions
ok() { echo -e '\e[32m'$domain'\e[m'; } # Green
die() { echo -e '\e[1;31m'$domain'\e[m'; exit 1; }

# Variables
#NGINX_AVAILABLE_VHOSTS='/etc/nginx/sites-available'
NGINX_ENABLED_VHOSTS='/etc/nginx/conf.d'
WEB_DIR=/var/www/html/$domain
WEB_USER=nginx

# Sanity check
[ $(id -g) != "0" ] && die "Script must be run as root."
#[ $# != "1" ] && die "Usage: $(basename $0) domainName"

# Creating {public document,log} directories
mkdir -p /var/log/nginx/$domain
mkdir -p /var/www/html/$domain

#eple release enable & enable amazon-linux-extras
#yum install epel-release -y
#yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
yum install -y amazon-linux-extras
amazon-linux-extras install epel -y
yum-config-manager --enable epel

#yum update and upgrade
yum update -y && yum upgrade -y

#enable php 7.4 and install
amazon-linux-extras enable php7.4
yum clean metadata
yum install php php-{opcache,tokenizer,common,mbstring,gd,bcmath,json,xml,zip,unzip} -y

#nginx installation
yum install nginx -y

#composer installion & and setup
curl -sS https://getcomposer.org/installer | php
mv composer.phar /usr/local/bin/composer
chmod +x /usr/local/bin/composer

# Create nginx config file
cat > $NGINX_ENABLED_VHOSTS/$domain-vhost.conf <<EOF
### www to non-www
server {
    listen 80;
    server_name $domain www.$domain;
    root /var/www/html/$domain/public;
   
    index index.html index.htm index.php;
   
    charset utf-8;

    location / {
        try_files $uri $uri/ /index.php$is_args$args;
    }
   
    location = /favicon.ico { access_log off; log_not_found off; }
    location = /robots.txt  { access_log off; log_not_found off; }

    
    access_log /var/log/nginx/$domain/$domain-access.log;
    
    error_log  /var/log/nginx/$domain/$domain-error.log error;

    location ~ /\.(?!well-known).* {
        deny all;
    }
}
EOF

# Git file configuration
yum install git -y && cd $WEB_DIR && git clone $URL

# Copy file .env.example file to .env
cp $WEB_DIR/$project/.env.example $WEB_DIR/$project/.env
sed -i 's/localhost/'$domain'/g' $WEB_DIR/$project/.env
sed -i 's/DB_HOST=127.0.0.1/DB_HOST='$mysql_endpoint'/g' $WEB_DIR/$project/.env
sed -i 's/DB_PASSWORD=/DB_PASSWORD='$mysql_root_pw'/g' $WEB_DIR/$project/.env

# Changing permissions
chown -R $WEB_USER:$WEB_USER $WEB_DIR
chmod 2775 $WEB_DIR && find $WEB_DIR -type d -exec sudo chmod 2775 {} \;
find $WEB_DIR -type f -exec sudo chmod 0664 {} \;
# Enable site by creating symbolic link
# ln -s $NGINX_AVAILABLE_VHOSTS/$1 $NGINX_ENABLED_VHOSTS/$1

# Restart
echo "Do you wish to restart nginx?"
select yn in "Yes" "No"; do
    case $yn in
        Yes ) service nginx restart ; break;;
        No ) exit;;
    esac
done

ok "Site Created for $domain"