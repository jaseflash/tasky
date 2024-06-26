#!/bin/bash
# CloudInit **** config files for checking issues and everything else ********
# stored in: /var/lib/cloud/instances/instance-id/user-data.txt
# logged at: /var/log/cloud-init-output.log
local_ip=`ip -o route get to 172.31.20.71 | sed -n 's/.*src \([0-9.]\+\).*/\1/p'`

# mongodb - /etc/mongod.conf
# log     - /var/log/mongodb/mongod.log
# data    - /var/lib/mongodb

sudo apt-get install gnupg curl

curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc | \
   sudo gpg -o /usr/share/keyrings/mongodb-server-7.0.gpg \
   --dearmor

# ******Using focal 20.04 seems to have lesser library issues *********

#echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list
echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/7.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list
sudo apt-get update
sudo apt-get install -y mongodb-org mongodb-mongosh unzip

# Troubleshooting hints -----> if mongo does not get enabled and sticks with issue
# check ownerships of these files and change
#sudo chown -R mongodb:mongodb /var/lib/mongodb
#sudo chown mongodb:mongodb /tmp/mongodb-27017.sock


# AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
sudo systemctl daemon-reload
sudo systemctl start mongod
sudo systemctl enable mongod
sleep 5

/usr/bin/mongosh <<- EOF
use admin
db.createUser(
  {
    user: "admin",
    pwd: "D0ntPwnMePls!",
    roles: [
      { role: "userAdminAnyDatabase", db: "admin" },
      { role: "readWriteAnyDatabase", db: "admin" }
    ]
  }
)
db.createUser(
  {
    user: "backup",
    pwd: "C@nY0uR3adThis!",
    roles: [
      { role: "backup", db: "admin" }
    ]
  }
)
db.createUser(
  {
    user: "tasky",
    pwd: "TaskMeIfY0uCan!",
    roles: [
      { role: "readWrite", db: "go-mongodb" }
    ]
  }
)
db.adminCommand( { shutdown: 1 } )
EOF


# Add Security Auth and bind to all interfaces
cat > /etc/mongod.conf <<- EOF
# mongod.conf

# for documentation of all options, see:
#   http://docs.mongodb.org/manual/reference/configuration-options/

# Where and how to store data.
storage:
  dbPath: /var/lib/mongodb
#  engine:
#  wiredTiger:

# where to write logging data.
systemLog:
  destination: file
  logAppend: true
  path: /var/log/mongodb/mongod.log

# network interfaces
net:
  port: 27017
  bindIp: 0.0.0.0

# how the process runs
processManagement:
  timeZoneInfo: /usr/share/zoneinfo

#security:
security:
  authorization: enabled

#operationProfiling:

#replication:

#sharding:

## Enterprise-Only Options:

#auditLog:
EOF

# Restart MongoDB with AuthN

sudo chown -R mongodb:mongodb /var/lib/mongodb
sudo chown mongodb:mongodb /tmp/mongodb-27017.sock
systemctl restart mongod

# Create directory for mongodb backups.
BACKUP_DIR="/var/log/mongodb/mongo-backup"
mkdir -p $${BACKUP_DIR}
cat > $${BACKUP_DIR}/env.sh <<- EOF
#!/bin/bash

# Your MongoDB's connection string
URI="mongodb://localhost:27017"

# The MongoDB database to be backed up
DBNAME=go-mongodb

# The MongoDB user
DBUSER=backup

# The MongoDB user passwd
DBPASS="C@nY0uR3adThis!"

# AWS Bucket Name
S3_BUCKET="s3://ext-mongodb-s3-backup/mongo/"

# Directory you'd like the MongoDB backup file to be saved to
DEST=$${BACKUP_DIR}/tmp
EOF

cat > $${BACKUP_DIR}/backup.sh <<- 'EOF'
#!/bin/bash
SCRIPT_DIR=$(cd $(dirname "$${BASH_SOURCE[0]}") && pwd)
source $${SCRIPT_DIR}/env.sh

PATH=$${PATH}:/usr/local/bin:/usr/local/sbin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin
# Current time and date
TIME=$(date +"%F-%H-%M-%S")

# Command to create a .tar file of the MongoDB backup files
TAR=$${DEST}/$${TIME}.full.tar.gz

# Command to create the backup directory
/bin/mkdir -p $${DEST}

# Echo for logging purposes
echo "Backing up $${URI}/$${DBNAME} to ${$S3_BUCKET} on $${TIME}";

# Command to run the mongodump command that dumps all data for the specified database to the backup directory
/usr/bin/mongodump --uri $${URI} --authenticationDatabase "admin" -u $${DBUSER} -p $${DBPASS} --out $${DEST}
# Create the .tar file of backup directory
echo "/bin/tar czvf $${TAR} -C $${DEST} ."
/bin/tar czvf $${TAR} -C $${DEST} .

# Upload the .tar to S3
echo "aws s3 cp $${TAR} s3://$${BUCKET}/"
aws s3 cp $${TAR} s3://$${S3_BUCKET}/

# Clean up
rm -rf $${DEST}/*

# Log the end of the script
echo "Backup completed and uploaded to S3"
EOF
mkdir -p $${BACKUP_DIR}/tmp
chown -R mongodb:mongodb $${BACKUP_DIR}
chmod 700 $${BACKUP_DIR}/backup-mongo.sh
chmod 750 $${BACKUP_DIR}/backup-mongo.sh
crontab -u root -l 2>/dev/null; echo "*/10 * * * * /var/log/mongodb/mongodb-backup/backup-mongo.sh > /var/log/mongodb/mongodb-backup/output.log 2>&1 | crontab -

# Examples:
# mongosh  --authenticationDatabase "admin" -u "admin" -p D0ntPwnMePls!
#
# use admin 
# db.auth("admin", "D0ntPwnMePls!")
#
# sudo mongodump --uri mongodb://localhost:27017 --authenticationDatabase "admin" -u "admin" -p D0ntPwnMePls!  --db admin --out /opt/mongodb-backups/tmp
# aws s3 cp /opt/mongodb-backups/tmp/admin s3://pp-s3-backup/ --recursive