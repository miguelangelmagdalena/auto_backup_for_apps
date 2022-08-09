#!/bin/bash

##################################################################################
##
##   Title: Script for the creation of backup of the BD and directories of Moodle using PostgreSQL
##   Official documentation:
##   1. Backup MySql https://cduser.com/como-automatizar-los-backup-de-mysql-con-un-script-y-crontab/
##   2. Backup MySql https://tecadmin.net/bash-script-mysql-database-backup/
##   3. Backup MySql https://jyzaguirre.wordpress.com/2014/10/06/programar-backup-mysql-en-linux-incluye-script/
##   4. Check space https://stackoverflow.com/questions/479276/how-to-find-out-the-free-disk-space-for-a-given-path-on-a-linux-shell
##
##################################################################################

##################################################################################
##
##   Data for backup configuration
##
##################################################################################

# 1. BACKUP_OPTIONS
BACKUP_BD=1
BACKUP_DIRROOT=1
BACKUP_DATAROOT=0
DELETE_OLD_BACKUPS=1

# 2. BD's Credentials PostgreSQL
DB_HOST="localhost"
DB_PORT="5432"
DB_NAME=""
DB_USER=""
DB_PASSWORD=""
DB_TYPE="psql"

# 3. App path
DIRROOT_PATH=""
DATAROOT_PATH=""

# 4. Backup path
BACKUP_PATH=""
BACKUP_LOG_LOCATION=""

# 5. Email for notifications
RECIPIENT_MAIL="mail@domain.com"
MAIL_ISSUE="[JOB BACKUP CVUCV]"

# 6. Number of days to store the backup 
KEEP_DAY=60

# 7. Date of backup
BACKUP_DATE_ONLY=$(date +"%d-%m-%Y")

# 8. Filenames
BACKUP_NAME="${BACKUP_PATH}/backup.${DB_TYPE}.${DB_NAME}.${BACKUP_DATE_ONLY}.utf8.custom.dump"
LOG_NAME="${BACKUP_LOG_LOCATION}/backup.${DB_TYPE}.${DB_NAME}.${BACKUP_DATE_ONLY}.log"

# To save echo outputs to a log file
exec > >(tee -a $LOG_NAME)
#exec 2>&1

##################################################################################
##
##   Functions
##
##################################################################################

# Make the calc for the actual timestamp
function BACKUP_DATE() {
    date +"%d-%m-%Y %T"
}

##################################################################################
##
##   1. Cheking Size
##
##################################################################################

FREE_SPACE=$(df -k ${BACKUP_PATH} | awk '$3 ~ /[0-9]+/ { print $4 }')
FREE_SPACE_GB=$(awk -v valor="${FREE_SPACE}" 'BEGIN{FREE_SPACE_GB=(valor/1024/1024); print FREE_SPACE_GB}')
OCCUPIED=$(du -k ${BACKUP_PATH} | cut -f1)
OCCUPIED_GB=$(awk -v valor="${OCCUPIED}" 'BEGIN{OCCUPIED_GB=(valor/1024/1024); print OCCUPIED_GB}')

echo "$(BACKUP_DATE) Free space is (GB): ${FREE_SPACE_GB} GB"
echo "$(BACKUP_DATE) Space occupied last backups (GB): ${OCCUPIED_GB} GB"

if (( $OCCUPIED_GB > $FREE_SPACE_GB )); then
  echo "$(BACKUP_DATE) Error: not enough space estimated"
  mail -s "${MAIL_ISSUE} Error: not enough space estimated" ${RECIPIENT_MAIL} < ${LOG_NAME}
  exit 1
fi

echo ""
##################################################################################
##
##   2. Credential Checks
##
##################################################################################

if [ $BACKUP_BD -eq 1 ]; then

    echo "$(BACKUP_DATE) Cheking connection to DB...."

    pg_isready -d$DB_NAME -h$DB_HOST -p$DB_PORT -U$DB_USER

    if [ $? -eq 0 ]; then
        echo "$(BACKUP_DATE) Connection to the DB working correctly"
    else
        echo "$(BACKUP_DATE) Error: Connection to the DB is not working!"
        mail -s "${MAIL_ISSUE} Error: Connection to the DB is not working!" ${RECIPIENT_MAIL} < ${LOG_NAME}
        exit 1
    fi

    echo ""
 
fi
##################################################################################
##
##   3. Making BACKUP
##
##################################################################################

if [ $BACKUP_BD -eq 1 ]; then
    # To make the backup in PostgreSQL, pg_dump is used, with the following parameters:
    # --encoding utf8: Create the backup with the specified character set (utf8 compatible with Moodle versions)
    # --host: Specifies the host name of the machine on which the database is running (in this case localhost)
    # --username: User with the respective privileges to connect to the DB
    # --dbname: Name of the database to be backed up

    echo "$(BACKUP_DATE) Starting pg_dump..."
    PGPASSWORD=${DB_PASSWORD} pg_dump --format custom --encoding utf8 --host ${DB_HOST} --port ${DB_PORT} --username ${DB_USER} --dbname ${DB_NAME} > ${BACKUP_NAME}

    if [ $? -eq 0 ]; then
        echo "$(BACKUP_DATE) Backup to the DB was successfull"
    else
        echo "$(BACKUP_DATE) Error during database backup creation"
        mail -s "${MAIL_ISSUE} Error during database backup creation" ${RECIPIENT_MAIL} < ${LOG_NAME}
        exit 1
    fi

    # We list the created file
    ls -lh ${BACKUP_NAME}
    echo ""

fi

##################################################################################
##
##   4. Deleting old backups
##
##################################################################################

if [ $DELETE_OLD_BACKUPS -eq 1 ]; then
    # We count files that are older than x days
    FILES_FOR_DELETE=$(find $BACKUP_PATH -type f -mtime +$KEEP_DAY -printf '.' | wc -c)

    if [ "${FILES_FOR_DELETE}" -gt 0 ]; then
        echo "These files will be deleted::"
        find $BACKUP_PATH -type f -mtime +$KEEP_DAY
        echo ""
        #find $BACKUP_PATH -type f -mtime +$KEEP_DAY -delete
        echo "Old files deleted"
    fi
    
    echo ""
fi

##################################################################################
##
##   5. Notifications
##
##################################################################################

FREE_SPACE=$(df -k ${BACKUP_PATH} | awk '$3 ~ /[0-9]+/ { print $4 }')
FREE_SPACE_GB=$(awk -v valor="${FREE_SPACE}" 'BEGIN{FREE_SPACE_GB=(valor/1024/1024); print FREE_SPACE_GB}')
OCCUPIED=$(du -k ${BACKUP_PATH} | cut -f1)
OCCUPIED_GB=$(awk -v valor="${OCCUPIED}" 'BEGIN{OCCUPIED_GB=(valor/1024/1024); print OCCUPIED_GB}')

echo "$(BACKUP_DATE) Free space after Backup (GB): ${FREE_SPACE_GB} GB"
echo "$(BACKUP_DATE) Space occupied after Backup (GB): ${OCCUPIED_GB} GB"

mail -s "${MAIL_ISSUE} Backup done satisfactorily!" ${RECIPIENT_MAIL} < ${LOG_NAME}

##################################################################################
##
##   Additional configuration of the Script for its operation
##
##################################################################################

# You must give execute permissions to this file.
# chmod +x auto_job_backup_bd_moodle_postgresql.sh

# Then you have to add it to the cron
# 30 4 * * * sh /path/auto_job_backup_bd_moodle_postgresql.sh

### End of script ####
