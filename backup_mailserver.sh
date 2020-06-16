#!/bin/sh
# Automatic backups for mail server
# Postfix, Dovecot, MySQL, Postfixadmin, Roundcube, ClamAV, Amavis
# By Douglas Barahona - douglas.barahona@me.com

# Working Directories and variables
TODAY=`date '+%d-%m-%Y'`
DAY16=`date '+%d-%m-%Y' -d "16 days ago"`
BACKUP_HOME=/backup
BACKUP_DAY16=$BACKUP_HOME/$DAY16.tar.gz
BACKUP_DIR=$BACKUP_HOME/$TODAY
MYSQL_ROOT_PASS=''
HOST=''
EMAILMESSAGE='' #Temp text file to store email notification body
S3_BUCKET='' #S3 Bucket name to store the final backup file.

# Clear email message and logs
echo 'Backup report for '$TODAY > $EMAILMESSAGE

# Remove backup from 16 days ago
if [ -f $BACKUP_DAY16 ]
then
rm -f $BACKUP_DAY16
echo 'File '$BACKUP_DAY16' has been removed' >> $EMAILMESSAGE
fi

# Create Directories
mkdir $BACKUP_DIR
mkdir $BACKUP_DIR/home
mkdir $BACKUP_DIR/certs
mkdir $BACKUP_DIR/private
mkdir $BACKUP_DIR/apache_conf
mkdir $BACKUP_DIR/web
mkdir $BACKUP_DIR/spool
cat <<EOF >> $EMAILMESSAGE

Temporary directory structure created
$BACKUP_DIR
$BACKUP_DIR/home
$BACKUP_DIR/certs
$BACKUP_DIR/private
$BACKUP_DIR/apache_conf
$BACKUP_DIR/web
$BACKUP_DIR/spool
EOF


# Backup all MySQL data and users
mysqldump -uroot -p$MYSQL_ROOT_PASS --events --databases mysql postfix roundcubemail > $BACKUP_DIR/mysql_backup_$TODAY.sql
cat <<EOF >> $EMAILMESSAGE

Creating MySQL backup
File $BACKUP_DIR/mysql_backup_$TODAY.sql
EOF

# Backup SSL Certificates
cp -p /etc/pki/tls/certs/$HOST.crt $BACKUP_DIR/certs/
cp -p /etc/pki/tls/private/$HOST.key $BACKUP_DIR/private/
cat <<EOF >> $EMAILMESSAGE

Backing up SSL Certificates
Copying /etc/pki/tls/certs/$HOST.crt to $BACKUP_DIR/certs/
Copying /etc/pki/tls/private/$HOST.key to $BACKUP_DIR/private/
EOF

# Backup Home directories
cp -pr /home/vmail $BACKUP_DIR/home/vmail/
cp -pr /home/sieve $BACKUP_DIR/home/sieve/
cat <<EOF >> $EMAILMESSAGE

Backing up /home directory
Copying /home/vmail to $BACKUP_DIR/home/vmail/
Copying /home/sieve to $BACKUP_DIR/home/sieve/
EOF

# Backup Postfixadmin files
cp -pr /usr/share/postfixadmin $BACKUP_DIR/web/postfixadmin
cp -p /etc/httpd/conf.d/postfixadmin.conf $BACKUP_DIR/apache_conf/
cat <<EOF >> $EMAILMESSAGE

Backing up Postfixadmin files
Copying /usr/share/postfixadmin to $BACKUP_DIR/web/postfixadmin
Copying /etc/httpd/conf.d/postfixadmin.conf to $BACKUP_DIR/apache_conf/
EOF

# Backup Postfix data
cp -pr /etc/postfix $BACKUP_DIR/postfix
cp -pr /var/spool/vacation $BACKUP_DIR/spool/vacation
cat <<EOF >> $EMAILMESSAGE

Backing up Postfix files
Copying /etc/postfix to $BACKUP_DIR/postfix
Copying /var/spool/vacation to $BACKUP_DIR/spool/vacation
EOF

# Backup Domain Keys
cp -pr /etc/mail/dkim-milter $BACKUP_DIR/dkim-milter
cat <<EOF >> $EMAILMESSAGE

Backing up Domain Keys
Copying /etc/mail/dkim-milter to $BACKUP_DIR/dkim-milter
EOF

# Backup Dovecot
cp -pr /etc/dovecot $BACKUP_DIR/dovecot
cat <<EOF >> $EMAILMESSAGE

Backing up Dovecot files
Copying /etc/dovecot to $BACKUP_DIR/dovecot
EOF

# Backup Roundcube
cp -pr /etc/roundcubemail $BACKUP_DIR/roundcubemail
cp -pr /usr/share/roundcubemail $BACKUP_DIR/web/roundcubemail
cp -p /etc/httpd/conf.d/roundcubemail.conf $BACKUP_DIR/apache_conf/
cat <<EOF >> $EMAILMESSAGE

Backing up Roundcube files
Copying /etc/roundcubemail to $BACKUP_DIR/roundcubemail
Copying /usr/share/roundcubemail to $BACKUP_DIR/web/roundcubemail
Copying /etc/httpd/conf.d/roundcubemail.conf to $BACKUP_DIR/apache_conf/
EOF

# Backup ClamAV
cp -pr /etc/clamd.d $BACKUP_DIR/clamd.d
cp -p /etc/clamd.conf $BACKUP_DIR/
cat <<EOF >> $EMAILMESSAGE

Backing up ClamAV files
Copying /etc/clamd.d to $BACKUP_DIR/clamd.d
Copying /etc/clamd.conf to $BACKUP_DIR/
EOF

# Backup Amavis
cp -pr /etc/amavisd $BACKUP_DIR/amavisd
cp -pr /var/spool/amavisd $BACKUP_DIR/spool/amavisd
cat <<EOF >> $EMAILMESSAGE

Backing up Amavis files
Copying /etc/amavisd to $BACKUP_DIR/amavisd
Copying /var/spool/amavisd to $BACKUP_DIR/spool/amavisd
EOF

# Compressing backup and remove temp directories
tar -zcf $BACKUP_HOME/$TODAY.tar.gz $BACKUP_DIR
rm -rf $BACKUP_DIR
cat <<EOF >> $EMAILMESSAGE

Compressing data and removing temporary files
$BACKUP_HOME/$TODAY.tar.gz file created
$BACKUP_DIR removed
EOF

# Sync files to S3
echo 'synchronizing files to S3' >> $EMAILMESSAGE
s3cmd sync --delete-removed $BACKUP_HOME s3://$S3_BUCKET/mail-server/ >> $EMAILMESSAGE

# Send confirmation email
SUBJECT='' #Email notification subject
FROMADDR='' #Email notification from address
EMAIL='' #Email notification destination address
mail -s "$SUBJECT" -r "$FROMADDR" "$EMAIL" < $EMAILMESSAGE