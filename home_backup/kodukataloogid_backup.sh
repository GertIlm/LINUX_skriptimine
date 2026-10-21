#!/bin/bash
# Õpetaja näidisskript (esimene versioon).
# NB! Töötab õigesti ainult siis, kui see käivitada /home/ kataloogis.

lahtekaust=$1
sihtkaust="/home_bcp"

for filename in $(ls $lahtekaust); do
    result=
    if [ -f $filename ]; then
        result="$filename is a regular file"
        echo $result
    else
        if [ -d $filename ]; then
            result="$filename is a directory Do BACKUP!"
            echo $result
            # arhiveerimiseks kasutame tar ja gzip
            kuupaev=`date +%d.%m.%Y`
            echo $kuupaev
            echo "$lahtekaust$filename/"
            tar -c -f $filename.$kuupaev.tar $filename/
            gzip $filename.$kuupaev.tar
            mv $filename.$kuupaev.tar.gz $sihtkaust
        fi
    fi
done
