#!/bin/bash
e=1

while getopts "N:" optKey; do
	case $optKey in
		
		N)
			N=$OPTARG
			;;
	esac
done

while [ $e -le $N ]
do
        function expect_password {
        expect -c "\
         set timeout 90
         set env(TERM)
         spawn $1
         expect \"*password:\"
         send \"magicword\r\"
        expect eof
        "
        }
    expect_password "ssh -t -o StrictHostKeyChecking=no node$e tmux send-keys -t whiteblock 'miner.start()' C-m"

(( e++ ))
done