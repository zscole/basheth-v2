#!/bin/bash

#loop to provide node variable function
while [ $e -le $N ]
do
        function expect_password {
        expect -c "\
         set timeout 90
         set env(TERM)
         spawn $1
         expect \"*password:\"
         send \"w@ntest\r\"
        expect eof
        "
        }

#ssh into node and start gubiq for auto mining
expect_password 'ssh -t -o StrictHostKeyChecking=no node$e tmux send-keys -t whiteblock 'miner.start()'

tmux send-keys -t whiteblock 'miner.start()


exit