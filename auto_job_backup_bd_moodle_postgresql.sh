#!/bin/bash

##################################################################################
##
##   Title: Script for the creation of backup of the BD and directories of Moodle using PostgreSQL
##   Official documentation:
##   1. Backup MySql https://cduser.com/como-automatizar-los-backup-de-mysql-con-un-script-y-crontab/
##   2. Backup MySql https://tecadmin.net/bash-script-mysql-database-backup/
##   3. Backup MySql https://jyzaguirre.wordpress.com/2014/10/06/programar-backup-mysql-en-linux-incluye-script/
##   4. Check space https://stackoverflow.com/questions/479276/how-to-find-out-the-free-disk-space-for-a-given-path-on-a-linux-shell
##   5. Using gmail with postfix in Ubuntu 18.04 https://kifarunix.com/configure-postfix-to-use-gmail-smtp-on-ubuntu-18-04/
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
BACKUP_DB_NAME="${BACKUP_PATH}/backup.${DB_TYPE}.${DB_NAME}.${BACKUP_DATE_ONLY}.utf8.custom.dump"
BACKUP_DIRROOT_NAME="${BACKUP_PATH}/backup.dirroot.${BACKUP_DATE_ONLY}.tar.gz"
BACKUP_DATAROOT_NAME="${BACKUP_PATH}/backup.dataroot.${BACKUP_DATE_ONLY}.tar.gz"
BACKUP_LOG_NAME="${BACKUP_LOG_LOCATION}/backup.log.${BACKUP_DATE_ONLY}.log"

# Threshold in GB (15GB)
THRESHOLD_FOR_BACKUP=15

# To save echo outputs to a log file
#exec >> $BACKUP_LOG_NAME
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

FREE_SPACE_GB=$(df -h ${BACKUP_PATH} | awk '$3 ~ /[0-9]+/ { print $4 }')
OCCUPIED_GB=$(du -sh ${BACKUP_PATH} | awk '{print $1; exit}')
FREE_SPACE=$(df -k ${BACKUP_PATH}  | awk '$3 ~ /[0-9]+/ { print $4 }')
FREE_SPACE_2=$(awk -v valor="${FREE_SPACE}" 'BEGIN{FREE_SPACE_GB=(valor/1024/1024); print FREE_SPACE_GB}')
FREE_SPACE_INT=${FREE_SPACE_2%.*}

echo "$(BACKUP_DATE) Free space is (GB): ${FREE_SPACE_GB} GB" >> $BACKUP_LOG_NAME
echo "$(BACKUP_DATE) Space occupied last backups (GB): ${OCCUPIED_GB} GB" >> $BACKUP_LOG_NAME

if (( $THRESHOLD_FOR_BACKUP > $FREE_SPACE_INT )); then
    echo "$(BACKUP_DATE) Error: not enough space estimated" >> $BACKUP_LOG_NAME
    mail -s "${MAIL_ISSUE} Error: not enough space estimated" ${RECIPIENT_MAIL} < ${BACKUP_LOG_NAME}
    exit 1
fi

echo "" >> $BACKUP_LOG_NAME
##################################################################################
##
##   2. DB Credential Checks
##
##################################################################################

if [ $BACKUP_BD -eq 1 ]; then

    echo "$(BACKUP_DATE) Cheking connection to DB...." >> $BACKUP_LOG_NAME

    pg_isready -d$DB_NAME -h$DB_HOST -p$DB_PORT -U$DB_USER >> $BACKUP_LOG_NAME

    if [ $? -eq 0 ]; then
        echo "$(BACKUP_DATE) Connection to the DB working correctly" >> $BACKUP_LOG_NAME
    else
        echo "$(BACKUP_DATE) Error: Connection to the DB is not working!" >> $BACKUP_LOG_NAME
        mail -s "${MAIL_ISSUE} Error: Connection to the DB is not working!" ${RECIPIENT_MAIL} < ${BACKUP_LOG_NAME}
        exit 1
    fi

    echo "" >> $BACKUP_LOG_NAME

fi

##################################################################################
##
##   3. Making DB BACKUP
##
##################################################################################

if [ $BACKUP_BD -eq 1 ]; then
    # To make the backup in PostgreSQL, pg_dump is used, with the following parameters:
    # --encoding utf8: Create the backup with the specified character set (utf8 compatible with Moodle versions)
    # --host: Specifies the host name of the machine on which the database is running (in this case localhost)
    # --username: User with the respective privileges to connect to the DB
    # --dbname: Name of the database to be backed up

    echo "$(BACKUP_DATE) Starting pg_dump..." >> $BACKUP_LOG_NAME
    PGPASSWORD=${DB_PASSWORD} pg_dump --format custom --encoding utf8 --host ${DB_HOST} --port ${DB_PORT} --username ${DB_USER} --dbname ${DB_NAME} > ${BACKUP_DB_NAME}

    if [ $? -eq 0 ]; then
        echo "$(BACKUP_DATE) Backup to the DB was successfull" >> $BACKUP_LOG_NAME
    else
        echo "$(BACKUP_DATE) Error during database backup creation" >> $BACKUP_LOG_NAME
        mail -s "${MAIL_ISSUE} Error during database backup creation" ${RECIPIENT_MAIL} < ${BACKUP_LOG_NAME}
        exit 1
    fi

    # We list the created file
    ls -lh ${BACKUP_DB_NAME} >> $BACKUP_LOG_NAME
    echo "" >> $BACKUP_LOG_NAME

fi

##################################################################################
##
##   4. Compressing Dirroot
##
##################################################################################

if [ $BACKUP_DIRROOT -eq 1 ]; then

    echo "$(BACKUP_DATE) Starting tar dirroot..." >> $BACKUP_LOG_NAME
    # As it is a directory with permissions for www-data, it is necessary to use 'sudo'
    #-czvf
    # -c: Create a new .tar file
    # -z: gzip compression
    # -f: File name

    if tar -czf ${BACKUP_DIRROOT_NAME} ${DIRROOT_PATH} 2>> $BACKUP_LOG_NAME
    then
        echo "$(BACKUP_DATE) Dirroot Backup was successfull" >> $BACKUP_LOG_NAME
    else
        echo "$(BACKUP_DATE) Error during dirroot backup creation" >> $BACKUP_LOG_NAME
        mail -s "${MAIL_ISSUE} Error during dirroot backup creation" ${RECIPIENT_MAIL} < ${BACKUP_LOG_NAME}
        exit 1
    fi

    ls -lh ${BACKUP_DIRROOT_NAME} >> $BACKUP_LOG_NAME
    echo "" >> $BACKUP_LOG_NAME
fi

##################################################################################
##
##   5. Compressing Dataroot
##
##################################################################################

if [ $BACKUP_DATAROOT -eq 1 ]; then

    if tar -czf ${BACKUP_DATAROOT_NAME_NAME} ${DATAROOT_PATH_PATH}
    then
        echo "$(BACKUP_DATE) Dirroot Backup was successfull" >> $BACKUP_LOG_NAME
    else
        echo "$(BACKUP_DATE) Error during dirroot backup creation" >> $BACKUP_LOG_NAME
        mail -s "${MAIL_ISSUE} Error during dirroot backup creation" ${RECIPIENT_MAIL} < ${BACKUP_LOG_NAME}
        exit 1
    fi

    ls -lh ${BACKUP_DIRROOT_NAME}
    echo "" >> $BACKUP_LOG_NAME
fi

##################################################################################
##
##   6. Deleting old backups
##
##################################################################################

if [ $DELETE_OLD_BACKUPS -eq 1 ]; then
    # We count files that are older than x days
    FILES_FOR_DELETE=$(find $BACKUP_PATH -type f -mtime +$KEEP_DAY -printf '.' | wc -c)

    if [ "${FILES_FOR_DELETE}" -gt 0 ]; then
        echo "These files will be deleted::" >> $BACKUP_LOG_NAME
        find $BACKUP_PATH -type f -mtime +$KEEP_DAY
        echo "" >> $BACKUP_LOG_NAME
        find $BACKUP_PATH -type f -mtime +$KEEP_DAY -delete
        echo "Old files deleted" >> $BACKUP_LOG_NAME
    fi

    echo "" >> $BACKUP_LOG_NAME
fi

##################################################################################
##
##   7. Notifications
##
##################################################################################

FREE_SPACE_GB=$(df -h ${BACKUP_PATH} | awk '$3 ~ /[0-9]+/ { print $4 }')
OCCUPIED_GB=$(du -sh ${BACKUP_PATH} | awk '{print $1; exit}')

echo "$(BACKUP_DATE) Free space after Backup (GB): ${FREE_SPACE_GB} GB" >> $BACKUP_LOG_NAME
echo "$(BACKUP_DATE) Space occupied after Backup (GB): ${OCCUPIED_GB} GB" >> $BACKUP_LOG_NAME

mail -s "${MAIL_ISSUE} Backup done satisfactorily!" ${RECIPIENT_MAIL} < ${BACKUP_LOG_NAME}

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
