#!/bin/bash
# LICENSE CDDL 1.0 + GPL 2.0
#
# Copyright (c) 1982-2016 Oracle and/or its affiliates. All rights reserved.
# 
# Since: November, 2016
# Author: gerald.venzl@oracle.com
# Description: Runs the Oracle Database inside the container
# 
# DO NOT ALTER OR REMOVE COPYRIGHT NOTICES OR THIS HEADER.
# 

########### Move DB files ############
function moveFiles {

   if [ ! -d $ORACLE_BASE/oradata/dbconfig/$ORACLE_SID ]; then
      mkdir -p $ORACLE_BASE/oradata/dbconfig/$ORACLE_SID/
   fi;

   mv $ORACLE_HOME/dbs/spfile$ORACLE_SID.ora $ORACLE_BASE/oradata/dbconfig/$ORACLE_SID/
   mv $ORACLE_HOME/dbs/orapw$ORACLE_SID $ORACLE_BASE/oradata/dbconfig/$ORACLE_SID/
   mv $ORACLE_HOME/network/admin/tnsnames.ora $ORACLE_BASE/oradata/dbconfig/$ORACLE_SID/

   # oracle user does not have permissions in /etc, hence cp and not mv
   cp /etc/oratab $ORACLE_BASE/oradata/dbconfig/$ORACLE_SID/
   
   symLinkFiles;
}

########### Symbolic link DB files ############
function symLinkFiles {

   if [ ! -L $ORACLE_HOME/dbs/spfile$ORACLE_SID.ora ]; then
      ln -s $ORACLE_BASE/oradata/dbconfig/$ORACLE_SID/spfile$ORACLE_SID.ora $ORACLE_HOME/dbs/spfile$ORACLE_SID.ora
   fi;
   
   if [ ! -L $ORACLE_HOME/dbs/orapw$ORACLE_SID ]; then
      ln -s $ORACLE_BASE/oradata/dbconfig/$ORACLE_SID/orapw$ORACLE_SID $ORACLE_HOME/dbs/orapw$ORACLE_SID
   fi;
   
   if [ ! -L $ORACLE_HOME/network/admin/tnsnames.ora ]; then
      ln -s $ORACLE_BASE/oradata/dbconfig/$ORACLE_SID/tnsnames.ora $ORACLE_HOME/network/admin/tnsnames.ora
   fi;

   # oracle user does not have permissions in /etc, hence cp and not ln 
   cp $ORACLE_BASE/oradata/dbconfig/$ORACLE_SID/oratab /etc/oratab

}

########### SIGINT handler ############
function _int() {
   echo "Stopping container."
   echo "SIGINT received, shutting down database!"
   sqlplus / as sysdba <<EOF
   shutdown immediate;
   exit;
EOF
   lsnrctl stop
}

########### SIGTERM handler ############
function _term() {
   echo "Stopping container."
   echo "SIGTERM received, shutting down database!"
   sqlplus / as sysdba <<EOF
   shutdown immediate;
   exit;
EOF
   lsnrctl stop
}

########### SIGKILL handler ############
function _kill() {
   echo "SIGKILL received, shutting down database!"
   sqlplus / as sysdba <<EOF
   shutdown abort;
   exit;
EOF
   lsnrctl stop
}

###################################
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! #
############# MAIN ################
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! #
###################################

# Check whether container has enough memory
# Github issue #219: Prevent integer overflow,
# only check if memory digits are less than 11 (single GB range and below) 
if [ `cat /sys/fs/cgroup/memory/memory.limit_in_bytes | wc -c` -lt 11 ]; then
   if [ `cat /sys/fs/cgroup/memory/memory.limit_in_bytes` -lt 2147483648 ]; then
      echo "Error: The container doesn't have enough memory allocated."
      echo "A database container needs at least 2 GB of memory."
      echo "You currently only have $((`cat /sys/fs/cgroup/memory/memory.limit_in_bytes`/1024/1024/1024)) GB allocated to the container."
      exit 1;
   fi;
fi;

# Set SIGINT handler
trap _int SIGINT

# Set SIGTERM handler
trap _term SIGTERM

# Set SIGKILL handler
trap _kill SIGKILL

# Start listener
lsnrctl start

# Start database
sqlplus / as sysdba << EOF
   STARTUP;
   exit;
EOF

echo "#########################"
echo "DATABASE IS READY TO USE!"
echo "#########################"

tail -f $ORACLE_BASE/diag/rdbms/*/*/trace/alert*.log &
childPID=$!
wait $childPID
