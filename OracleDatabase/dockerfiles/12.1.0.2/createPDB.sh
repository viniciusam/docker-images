#!/bin/bash

if [ -z "$1" ]; then
  ORACLE_PDB="ORCLPDB1"
else
  ORACLE_PDB="$1"
fi

# Replace place holders in response file
cp $ORACLE_BASE/$PDB_RSP $ORACLE_BASE/pdb.rsp
sed -i -e "s|###ORACLE_SID###|$ORACLE_SID|g" $ORACLE_BASE/pdb.rsp
sed -i -e "s|###ORACLE_PDB###|$ORACLE_PDB|g" $ORACLE_BASE/pdb.rsp
sed -i -e "s|###ORACLE_PWD###|$ORACLE_PWD|g" $ORACLE_BASE/pdb.rsp

# Create the new PDB
dbca -silent -responseFile $ORACLE_BASE/pdb.rsp

echo "$ORACLE_PDB= 
(DESCRIPTION = 
  (ADDRESS = (PROTOCOL = TCP)(HOST = 0.0.0.0)(PORT = 1521))
  (CONNECT_DATA =
    (SERVER = DEDICATED)
    (SERVICE_NAME = $ORACLE_PDB)
  )
)" >> $ORACLE_HOME/network/admin/tnsnames.ora

# Remove second control file, create PDB and make PDB auto open
sqlplus / as sysdba << EOF
   ALTER SYSTEM SET control_files='$ORACLE_BASE/oradata/$ORACLE_SID/control01.ctl' scope=spfile;
   ALTER PLUGGABLE DATABASE $ORACLE_PDB SAVE STATE;
   exit;
EOF

# Remove temporary response file
rm $ORACLE_BASE/pdb.rsp
