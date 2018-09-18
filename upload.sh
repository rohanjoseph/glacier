#!/bin/bash

DIR=/home/{user}/{directory} #directory can be hardcoded if necessary or depending the scenario
DBFILENAME=/home/{user}/{directory}/database #file which is going to be uploaded for multipart
SIZE=1048576 #chunk size can vary from 1 mb to 4gb
CHUNKNAME=/home/{user}/{directory}/{subDirectory}/database #name of the chunk
DATA=/home/{user}/{directory}/{subDirectory}
ACCOUNT_ID=<12 digit aws account id>
VAULT_NAME=<vault-name>
REGION_ID=<region-id>
MULTIPART_DESCRIPTION=<description can be anything>
GLACIER_MUTLIPART_COMMANDS=</home/{user}/{directory}/text.txt> #hardcoded text file path where you can store command for a while like 
GLACIER_CKSUM=</home/{user}/{directory}/text.txt> #hardcoded text file path where you can store checksum.
STATUS_CHECK=/home/{user}/{directory}/{subDirectory}/statusCheck.$(date +"%Y%m%d_%H%M%S").txt
TREEHASH_LIB=/usr/local/bin/treehash #treehash hash bin path which will be available after installing ruby gem

#Below one removes the temporary files present in the directory
rm -f $GLACIER_CKSUM $GLACIER_MUTLIPART_COMMANDS  

#This will remove any splitted parts present of the previous upload. This is just to confirm that there is a fresh installation
rm -rf $DATA/* 

#Creating multiple files 
touch $GLACIER_CKSUM $GLACIER_MUTLIPART_COMMANDS

#checking if Glacier vault is present or not
VAULT_LIST=`aws glacier list-vaults --account-id $ACCOUNT_ID --region $REGION_ID | awk '/VaultName/{print $2}' | tr -d '",'`

for vaultName in $VAULT_LIST; do
echo $vaultName
   if [[ "$vaultName" == "$VAULT_NAME" ]]
    then
        echo "Vault Present in the amazon glacier";
        break
  else
        echo "Please create the vault in the amaon glacier";
   fi
done


#aws splitting the sql file into the mulit-parts

split --bytes=$SIZE --verbose $DBFILENAME $CHUNKNAME

#initiate multipart upload
UPLOAD_ID=`aws glacier initiate-multipart-upload --account-id $ACCOUNT_ID --archive-description "multipart upload test"  --part-size $SIZE  --vault-name $VAULT_NAME --region $REGION_ID | awk '/uploadId/{print $2}' | tr -d '",'`

echo $UPLOAD_ID

#uploading files into the glacier repository
i=0
for items in $DATA/*
do
byteStart=$((i*$SIZE))
byteEnd=$((i*$SIZE+$SIZE-1))

if [ $(wc -c <$items) == $SIZE ]
then
echo aws glacier upload-multipart-part --upload-id $UPLOAD_ID --body $items  --range "'"'bytes '"${byteStart}"'-'"${byteEnd}"'/*'"'" --account-id $ACCOUNT_ID --vault-name $VAULT_NAME --region $REGION_ID >> $GLACIER_MUTLIPART_COMMANDS
else
FILE_SIZE=$(wc -c <$items)
byteEnd=$((byteStart+$FILE_SIZE-1))
echo aws glacier upload-multipart-part --upload-id $UPLOAD_ID --body $items  --range "'"'bytes '"$byteStart"'-'"$byteEnd"'/*'"'" --account-id $ACCOUNT_ID --vault-name $VAULT_NAME --region $REGION_ID >> $GLACIER_MUTLIPART_COMMANDS
fi
i=$(($i+1))
#echo $items
#echo $i
done

echo "uploading file "
parallel --load 100% -a $GLACIER_MUTLIPART_COMMANDS --no-notice --bar >> $GLACIER_CKSUM

#Calculating treehash value 
echo "Calculating the treehash value of the file"
CKVALUE=$($TREEHASH_LIB $DBFILENAME)
echo $CKVALUE
#completing the upload

echo "substituting treehash value in the aws command line "
ARCHIVE_SIZE=$(wc -c <$DBFILENAME)
#aws glacier complete-multipart-upload --checksum $CKVALUE --archive-size $ARCHIVE_SIZE --upload-id $UPLOAD_ID --account-id $ACCOUNT_ID --vault-name $VAULT_NAME --region $REGION_ID >> $STATUS

STATUS=`aws glacier complete-multipart-upload --checksum $CKVALUE --archive-size $ARCHIVE_SIZE --upload-id $UPLOAD_ID --account-id $ACCOUNT_ID --vault-name $VAULT_NAME --region $REGION_ID`

echo "Archive ID"
ARCHIVE_ID=`echo $STATUS | jq --raw-output '.archiveId'`
echo $ARCHIVE_ID

echo "Archive Location"
ARCHIVE_LOCATION=`echo $STATUS | jq --raw-output '.location'`
echo $ARCHIVE_LOCATION

echo "Archive Checksum"
ARCHIVE_CHECKSUM=`echo $STATUS | jq --raw-output '.checksum'`
echo $ARCHIVE_CHECKSUM

#Storing the details of the object upload

echo $STATUS >> $STATUS_CHECK

echo "upload complete.. it will take take time to reflect into the amazon glacier.. please be patient"
#STATUS OF THE ARCHIVE 
echo "describing vault to get the details"
aws glacier describe-vault --account-id $ACCOUNT_ID --vault-name $VAULT_NAME --region $REGION_ID  >> $STATUS

