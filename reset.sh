#!/bin/bash


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
    expect_password "ssh -t -o StrictHostKeyChecking=no node$e rm -R /home/appo/node$e"
(( e++ ))
done