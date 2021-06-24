#dependencies
jq


# Instructions to use

## Env
source zephyr-env.sh

##Get IDs for the batch -- need output filename and batchsize

./gen_ids_batch.sh -f <output-filename> -b <batch-size>

Ex: ./gen_ids_batch.sh -f ids_generated/batch276-ids.text -b 2

##Flash new acruxs from the new IDs generated

./zedblox_automation/new_id_acrux.sh -b <board_name> -p <version | 4l or 15l> -f <id_gen_filename> <-s | skip or not>

Ex: ./zedblox_automation/new_id_acrux.sh -b zb_acrux_vp1_0_revb -p 15l -f zedblox_automation/ids_generated/test.txt -s
