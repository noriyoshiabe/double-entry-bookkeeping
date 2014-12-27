#!/bin/bash

mkdir -p out/
SHEETS=(`mysql -u root 複式簿記 -N -s -e 'SHOW TABLES LIKE "%印刷用"' | tr '\n' ' '`)
for sheet in ${SHEETS[@]}; do
    mysql -u root 複式簿記 --table -e "SELECT * FROM $sheet" > out/${sheet%_印刷用}.txt
    mysql -u root 複式簿記 -e "SELECT * FROM $sheet" | tr '\t' ',' > out/${sheet%_印刷用}.csv
    mysql -u root 複式簿記 -e "SELECT * FROM $sheet" | tr '\t' ',' | nkf -s > out/excel_${sheet%_印刷用}.csv
done
