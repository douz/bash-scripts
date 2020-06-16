#!/bin/bash
#
# Install Lucee and Nginx on RHEL 6 x86_64 servers
# Author: Douglas Barahona - douglas.barahona@me.com

#Initialize Variables
TODAY=`date '+%d-%m-%Y'`
SCRIPT_NAME="Lucee Go"
VERSION="1.0"
TEMP_DIR="/tmp/lucee-install/"
ADMIN_PASS="" #Default admin passowrd
USR_PASS="" #Default user password
CPU_COUNT=`cat /proc/cpuinfo | grep processor | wc -l`

#Display command help function
exit_help() {
    more <<EOF
    MANUAL

    NAME
        luceego - lucee good to go - APM.

    SYNOPSIS
        luceego.sh [-v] [-h] [-t [=<path>]] [-a [=<value>]] -u [=<value>]

    DESCRIPTION
        This script will install Lucee and Nginx on RHEL 6 x86_64 servers. 

    The inclusion or exclusion of any part, depends on the parameters sent to the script.

    OPTIONS
        -v Version
            Prints the "luceego" current version.

        -h Help
            Prints the synopsis and a list of the most commonly used commands.
               
        -t Temporary path
            Specify the temporary path for downloads. This directory will be removed after the script is complete

        -a Default admin password
            Set the default password for the Lucee administrator

        -u Default user password
            Set the default password for the lucee and nginx OS users

    AUTHORS
    This script is maintained by Douglas Barahona - douglas.barahona@me.com.

EOF
    exit 1
}

#Display command usage function
exit_usage () {
    cat <<EOF
    COMMAND USAGE
    luceego.sh [-v] [-h] [-t [=<path>]] [-a [=<value>]] -u [=<value>]

    For more help run: luceego.sh -h
EOF
    exit 1
}

#Display command version function
exit_version() {
    cat <<EOF
    $SCRIPT_NAME Version $VERSION
    `uname -mrs`
EOF
    exit 1
}

#read and process arguments
while getopts ":t:a:u: vh" opt
do
    case $opt in
        v ) exit_version ;;
        h ) exit_help ;;
        t ) TEMP_DIR=$OPTARG ;;
        a ) ADMIN_PASS=$OPTARG ;;
        u ) USR_PASS=$OPTARG ;;
        \? ) echo "Invalid option -$OPTARG"
            exit_usage ;;
        : ) echo "Option -$OPTARG requires an argument"
            exit_usage ;;
    esac
done
shift $((OPTIND-1))

#Display usage if unaccepted characters are typed in
if [ -n "$1" ]; then
    exit_usage
fi

#Create lucee user and group
echo "Creating lucee OS group and user"
groupadd -g 1900 lucee
useradd -u 1900 -g lucee -c "Lucee Admin Account" lucee
echo "lucee:$USR_PASS" | chpasswd

#Create nginx user and group
echo "Creating nginx OS group and user"
groupadd -g 2200 nginx
useradd -u 2200 -g nginx -c "Nginx Admin Account" nginx
echo "nginx:$USR_PASS" | chpasswd

#Create temp dir
echo "Creating temporary directory" $TEMP_DIR
mkdir -p $TEMP_DIR

#Install Nginx and start the service
echo "Downloading and installing Nginx repository"
wget -P $TEMP_DIR http://nginx.org/packages/centos/6/noarch/RPMS/nginx-release-centos-6-0.el6.ngx.noarch.rpm
rpm -ivh $TEMP_DIR/nginx-release-centos-6-0.el6.ngx.noarch.rpm
echo "Installing Nginx"
yum -y install nginx
echo "Starting Nginx service"
service nginx start
chkconfig nginx on

#Install Lucee
echo "Downloading and installing Lucee"
wget http://cdn.lucee.org/downloader.cfm/id/170/file/lucee-5.1.0.034-pl0-linux-x64-installer.run -O $TEMP_DIR/lucee.run
chmod 775 $TEMP_DIR/lucee.run
$TEMP_DIR/lucee.run --mode unattended --luceepass $ADMIN_PASS --installconn false

#Change runtime user for lucee
echo "Changing Lucee runtime user to "lucee""
/opt/lucee/sys/change_user.sh lucee /opt/lucee/ lucee nobackup
chown -R lucee:lucee /opt/lucee

#Tunning nginx.conf
echo "Appling basic configuration to nginx.conf file"
cat <<EOF > /etc/nginx/nginx.conf
#################################################
## Modified by luceego.sh
## $TODAY
#################################################
user  nginx;
worker_processes  $CPU_COUNT;

error_log  /var/log/nginx/error.log error;
pid        /var/run/nginx.pid;


events {
    worker_connections  1024;
}


http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;
    server_tokens off;
    real_ip_header X-Real-IP;
    set_real_ip_from 0.0.0.0/0;

    log_format main '\$remote_addr - \$remote_user [\$time_local] \$request '
                    '\$status \$body_bytes_sent  '
                    '\$http_user_agent \$http_x_forwarded_for';

    access_log  /var/log/nginx/access.log  main;

    sendfile        on;
    tcp_nopush      on;

    keepalive_timeout  30;

    ##################
    #gzip compression#
    ##################

    gzip on;
    gzip_disable msie6;
    # gzip_static on;
    gzip_min_length 1400; 
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 9;
    gzip_buffers 16 8k;
    gzip_http_version 1.1;
    gzip_types
      application/atom+xml
      application/javascript
      application/json
      application/rss+xml
      application/vnd.ms-fontobject
      application/x-font-ttf
      application/x-web-app-manifest+json
      application/xhtml+xml
      application/xml
      font/opentype
      image/svg+xml
      image/x-icon
      text/css
      text/plain
      text/x-component;

    server_names_hash_bucket_size 64;
    include /etc/nginx/conf.d/*.conf;
}
EOF

#Creating Lucee connector /etc/nginx/lucee.conf
echo "Creating Lucee connector /etc/nginx/lucee.conf"
cat <<EOF > /etc/nginx/lucee.conf
#################################################
## lucee.conf Added by luceego.sh
## $TODAY
#################################################
location / {
  # Rewrite rules and other criterias can go here
  # Remember to avoid using if() where possible (http://wiki.nginx.org/IfIsEvil)
  try_files \$uri \$uri/ @rewrites;

}

location @rewrites {
    # Can put some of your own rewrite rules in here
    # for example rewrite ^/~(.*)/(.*)/? /users/$1/$2 last;
    rewrite ^/(.*)? /index.cfm/\$1 last;
    rewrite ^ /index.cfm last;
}

location /lucee/admin/ {
    internal;
    proxy_pass http://127.0.0.1:8888;
    proxy_redirect off;
    proxy_http_version 1.1;
    proxy_set_header Host \$host;
    proxy_set_header X-Forwarded-Host \$host;
    proxy_set_header X-Forwarded-Server \$host;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Real-IP \$remote_addr;
}

# Main Lucee proxy handler
location ~ \.(cfm|cfml|cfc|jsp|cfr)(.*)$ {
    proxy_pass http://127.0.0.1:8888;
    proxy_redirect off;
    proxy_http_version 1.1;
    proxy_set_header Host \$host;
    proxy_set_header X-Forwarded-Host \$host;
    proxy_set_header X-Forwarded-Server \$host;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Real-IP \$remote_addr;
}
EOF

#Changing ownership of nginx config files
echo "Changin ownsership of nginx config files to nginx:nginx"
chown -R nginx:nginx /etc/nginx

#Removing temp dir
echo "Removing temporary directory"
rm -rf $TEMP_DIR

#Restat services
echo "Restarting Services"
/opt/lucee/lucee_ctl restart
service nginx restart

#Showing completion message
echo "*********************"
echo "* Process Completed *"
echo "*********************"