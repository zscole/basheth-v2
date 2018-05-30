#!/bin/bash
ps -ef | grep gubiq | grep -v grep | awk '{print $2}' | xargs kill
f=$(echo /home/appo/node*)
n=`echo $f | cut -c 12-17`
w=$(sed 's/^[^{]*{\([^{}]*\)}.*/\1/' /home/appo/node*/wallet)
gubiq --datadir /home/appo/$n --networkid 17835 --rpc --unlock $w --password /home/appo/$n/passwd.file --rpc console