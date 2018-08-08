#!/bin/bash

N=10
e=1

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
    expect_password "ssh -t -o StrictHostKeyChecking=no node$e tmux new -s transactions -d"
    expect_password "ssh -t -o StrictHostKeyChecking=no node$e tmux send-keys -t transactions 'cd /home/appo/auto_txs && node transaction.js' C-m"
(( e++ ))
done