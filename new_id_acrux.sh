#!/bin/bash

BOARD_NAME=""
DEV_ID=""
DEV_ID_FILE=""
PLATFORM_CONFIG=""

SKIP_TEST=0

PATH_CONFIG="${ZEPHYR_BASE}/zbacrux_setup/src"
CONFIG_FILE_NAME="config.h"

# Loop through arguments and process them
for arg in "$@"
do
    case $arg in
        -d|--dest-dir)
            shift # Remove name from processing
            PATH_CONFIG="$1"
            shift # Remove value from processing
            ;;
        -b|--bname)
            shift
            BOARD_NAME="$1"
            shift
            ;;
        -i|--dev-id)
            shift
            DEV_ID="$1"
            shift
            ;;
        -f|--ids-file)
            shift
            DEV_ID_FILE="$1"
            shift
            ;;
        -p|--platform)
            shift
            PLATFORM_CONFIG="$1"
            shift
            ;;
        -s|--skip-test)
            shift
            SKIP_TEST=1
            ;;
        -h| --help)
            shift
            echo "Help menu"
            # TODO
            shift
            exit 0
            ;;
    esac
done

# source automation env
source $ZEPHYR_BASE/zedblox_scripts/zb_auto.sh

P_1="4L"
P_2="15L"
PLATFORM_OPT=0
PLAT_SEL=$P_1

shopt -s nocasematch
case "$PLATFORM_CONFIG" in
     $P_1 ) echo "Platform: ${P_1}"; PLAT_SEL=$P_1; PLATFORM_OPT=0;;
     $P_2 ) echo "Platform: ${P_2}"; PLAT_SEL=$P_2; PLATFORM_OPT=1;;
      *) echo "Please select the right platform"; exit 1;;
esac

shopt -s nocasematch

if [ "$BOARD_NAME" = "" ]; then
    echo "ERROR: BOARD_NAME mentioned"
    exit 1
fi

if [ "$DEV_ID" = "" ] && [ "$DEV_ID_FILE" = "" ]; then
    echo "ERROR: No way to get IDs"
    exit 1
fi

if [ "$DEV_ID_FILE" != ""  ]; then
    DEV_ID=$(sed -n '1p' < ${DEV_ID_FILE}.acrux  | sed 's/"//g')
fi

echo "Device ID chosen: ${DEV_ID}"

# Make the config file from the default config and id given on cmd line
echo "#ifndef __CONFIG_H__" > $PATH_CONFIG/$CONFIG_FILE_NAME
echo "#define __CONFIG_H__" >> $PATH_CONFIG/$CONFIG_FILE_NAME
cat $PATH_CONFIG/default_config >> $PATH_CONFIG/$CONFIG_FILE_NAME
echo "#define DEVICE_ID_DEF  \"$DEV_ID\"" >> $PATH_CONFIG/$CONFIG_FILE_NAME
echo "#endif" >> $PATH_CONFIG/$CONFIG_FILE_NAME

# flush echo to persistent storage
sync

echo "Flashing setup firmware..."

### Testing phase

west flash --build-dir build/$BOARD_NAME/mcuboot/ --softreset -r nrfjprog

#west build -b zb_acrux_vp1_0_revb zbacrux_unit_testing; west sign -t imgtool -d build/zb_acrux_vp1_0_revb/zbacrux_unit_testing/ -- --key ../bootloader/mcuboot/zb-ed25519.pem; west flash --build-dir build/zb_acrux_vp1_0_revb/zbacrux_unit_testing/ -r nrfjprog --hex-file build/zb_acrux_vp1_0_revb/zbacrux_unit_testing/zephyr/zephyr.signed.hex --softreset

if [ $SKIP_TEST -eq 0 ]; then
    west flash --build-dir build/$BOARD_NAME/zbacrux_unit_testing/ -r nrfjprog --hex-file zedblox_scripts/images/$BOARD_NAME/$APP_ACRUX_MODEM_FLASH_FILE --softreset

    echo "Please go and flash the modem with new firmware. Check if modem LEDs are blinking or not. They have to blink before flashing modem firmware"

    # Check for cont
    while  true; do
        # confirmation string after modem flash
        read -n 5 -p "Type [cont] to move forward after modem flash:              " inputstr

        if [ "$inputstr" = "cont" ]; then
            echo "Continuing..."
            break
        fi
    done
fi

#west flash --build-dir build/$BOARD_NAME/zbacrux_setup/ -r nrfjprog --hex-file build/$BOARD_NAME/zbacrux_setup/zephyr/zephyr.signed.hex --softreset

# flash the setup firmware
west build -b $BOARD_NAME zbacrux_setup; west sign -t imgtool -d build/$BOARD_NAME/zbacrux_setup/ -- --key ../bootloader/mcuboot/zb-ed25519.pem; west flash --build-dir build/$BOARD_NAME/zbacrux_setup/ -r nrfjprog --hex-file build/$BOARD_NAME/zbacrux_setup/zephyr/zephyr.signed.hex --softreset

if [ $? -eq 0 ]; then
    echo "[Sucess] Setup firmware DONE!"
else
    echo "[Error] setup firmware flash failed!!"
    exit 1
fi

# give some time for setup to complete
sleep 10

if [ $SKIP_TEST -eq 0 ]; then
    echo "Flashing test firmware [started]..."

    #west build -b $BOARD_NAME zb_actipod_app; west sign -t imgtool -d build/$BOARD_NAME/zb_actipod_app/ --key ../bootloader/mcuboot/zb-ed25519.pem; west flash --build-dir build/$BOARD_NAME/zb_actipod_app/ -r nrfjprog --hex-file build/$BOARD_NAME/zb_actipod_app/zephyr/zephyr.signed.hex --softreset

    west flash --build-dir build/$BOARD_NAME/zb_actipod_app/ -r nrfjprog --hex-file zedblox_scripts/images/$BOARD_NAME/$APP_ACRUX_TEST_FILE --softreset

    if [ $? -eq 0 ]; then
        echo "[Sucess] Testing firmware flashed..."
    else
        echo "[Error] Testing firmware flash FAILED!"
        exit 1
    fi

    # Check for cont
    while  true; do
        # confirmation string after modem flash
        read -n 5 -p "Type [cont] to move to final platform app flash:              " inputstr

        if [ "$inputstr" = "cont" ]; then
            echo "Continuing..."
            break
        fi
    done
fi

# TODO move the following to a new helper script
APP_FW_FILE=""
if [ $PLATFORM_OPT -eq 0 ]; then
    APP_FW_FILE=$APP_4L_FW_FILE
else
    APP_FW_FILE=$APP_15L_FW_FILE
fi

west flash --build-dir build/$BOARD_NAME/zb_actipod_app/ -r nrfjprog --hex-file zedblox_scripts/images/$BOARD_NAME/$APP_FW_FILE --softreset

if [ $? -eq 0 ]; then
    echo "[Sucess] FINAL APP firmware flashed..."
else
    echo "[Error] FINAL APP firmware flash FAILED!"
    exit 1
fi

# Check for cont
while true; do
    read -n 2 -p "Is flash successful? CAUTION -- CHECK CAREFULLY -- Type y/n to confirm:              " inputstr

    if [ "$inputstr" = "y" ]; then
        echo "Flash success... ID: ${DEV_ID}"

        ### Process acrux and all ids files to move done ids to a done file
        # move the done ids to a different file
        if [ "$DEV_ID_FILE" != ""  ]; then
            sed -n '1p' < ${DEV_ID_FILE}.acrux >> ${DEV_ID_FILE}.acrux.done
            sed -n '1p' < ${DEV_ID_FILE}.all >> ${DEV_ID_FILE}.all.done
            sed -i '1d' ${DEV_ID_FILE}.acrux
            sed -i '1d' ${DEV_ID_FILE}.all
        fi
        break
    elif [ "$inputstr" = "n" ]; then
        echo "ERROR: Flash failed... ID: ${DEV_ID}"
        exit 1
    else
        echo "**Enter the right choice**"
    fi
done

echo "****DONE FLASHING NEW ACRUX BOARD - ID: ${DEV_ID}, PLATFORM: ${PLAT_SEL}****"
