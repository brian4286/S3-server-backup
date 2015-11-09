#!/bin/bash
#title		:s3-server-backup.sh
#description	:Backup nginx configs, website data and dumps db's with innobackupex or mysqldump
#author		:https://github.com/brian4286
#version	:2015011601
#usage		:cron
#notes		:Assuming Debian layout, you have XtraBackup backup and S3. Not much checking here, pretty dumb.


#
# CONFIGUTATION
#
date=$(date +"%m_%d_%Y")
backup_location=
max_number_of_backups=14
bucket=

# Make sure backup directory's are created
mkdir -p $backup_location/tmp/

# Clean up
rm -Rf $backup_location/tmp/*

# Backup nginx configs
cd /etc; tar cf $backup_location/tmp/nginx_$date.tar nginx/

# Backup websites's
cd /usr/share/nginx; tar cf $backup_location/tmp/www_$date.tar www/
cd $backup_location/tmp

# Dumps databases one-by-one
innobackupex --compress --compress-threads=4 .
#mysql -Bse "show databases" | grep -Ev "(_schema|mysql|tmp|innodb)" | while read db; do mysqldump $db > $db.sql; done

# Compress all the new files
cd ..; tar cjf $date.tbz2 tmp/

# Time to do backup rotation
function number_of_backups() {
    ls -1 $backup_location | wc -l
}

# Removing old locally
while [ $(number_of_backups) -gt $max_number_of_backups ]
do
    rm -rf $backup_location/`ls -tr1 $BACKUP_LOCATION | head -1`
done

# This will sync local backup's with remote backups
s3cmd sync --exclude 'tmp/*' --delete-removed --rr $backup_location s3://$bucket
