#!/bin/bash

BATCH_SIZE=0
STORE_PATH_CONFIG=""

# Loop through arguments and process them
for arg in "$@"
do
    case $arg in
        -f|--file)
            shift # Remove from processing
            STORE_PATH_CONFIG="$1"
            shift # Remove from processing
            ;;
        -b|--batchsz)
            shift # Remove argument name from processing
            BATCH_SIZE=$1
            shift # Remove argument value from processing
            ;;
        -h|--help)
            shift # Remove argument name from processing
            echo "Help menu"
            shift # Remove argument value from processing
            exit 0
            ;;
    esac
done

if [ "$STORE_PATH_CONFIG" = "" ]; then
    echo "ERROR: no output file mentioned"
    exit 1
fi

if [ BATCH_SIZE -eq 0 ]; then
    echo "ERROR: no batch size mentioned"
    exit 1
fi

echo "OUTPUT FILE: ${STORE_PATH_CONFIG}"
echo "BATCH_SIZE: ${BATCH_SIZE}"

echo "Fetching IDs..."

OUTPUT=$(curl -k --location --request POST "https://44.233.13.28:3500/api/v1.0/admin/login" --header "Content-Type: application/json" --data-raw '{"adminID":"zedblox","password":"12345678"}')

LOGIN_TOKEN=$(echo $OUTPUT | jq '.token'| sed 's/"//g')

#echo $LOGIN_TOKEN

touch $STORE_PATH_CONFIG.acrux
touch $STORE_PATH_CONFIG.all

truncate -s 0 $STORE_PATH_CONFIG.acrux
truncate -s 0 $STORE_PATH_CONFIG.all

for ((i = 0 ; i < $BATCH_SIZE; i++)); do
    OUTPUT=$(curl -k --location --request GET "https://44.233.13.28:3500/api/v1.0/electrical/id/generate" --header "x-auth-token:${LOGIN_TOKEN}")

    # HACK FIXME
    #echo "######${i}######" >> $STORE_PATH_CONFIG.acrux
    echo $OUTPUT >> $STORE_PATH_CONFIG.all
    #echo "################" >> $STORE_PATH_CONFIG.acrux

    ACRUX_ID=$(echo $OUTPUT | jq '.kitIdList' | jq '.acruxBrdId' | sed 's/"//g')

    echo "ACRUX_ID: ${ACRUX_ID}"

    echo $ACRUX_ID >> $STORE_PATH_CONFIG.acrux
done
