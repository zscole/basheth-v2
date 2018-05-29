#!/bin/bash

rm -rf /home/appo/node*

function usage {
        cat <<EOM
     Usage: create_block -c <chainId> -n <networkid> -N <Number of nodes>
     Example: create_block -c 17835211 -n 178354 -N 12
EOM
    exit 1
}

c=17835
n=17835

while getopts ":c:n:N:h" optKey; do
    case $optKey in
        c)
            c=$OPTARG
            ;;
        n)
            n=$OPTARG
            ;;
	N)
            N=$OPTARG
            ;;
        h|*)
            usage
            ;;
    esac
done

# Create the CustomGenesis.json file

cat <<EOF > /tmp/CustomGenesis.json
{
    "config": {
        "chainId": $c,
        "homesteadBlock": 0,
        "eip155Block": 0,
        "eip158Block": 0
    },
    "difficulty": "0x0400",
    "gasLimit": "0x2100000",
    "alloc": {}
}
EOF


rm /tmp/static-nodes.json

i=1
while [ "$i" -le "$N" ]; do

    count=$i
    # set the ip address for the enode
    nodeIP=10.$i.100.100

    echo "---------------------  CREATING block directory for NODE-$i  ---------------------"
    # Create the node directory
    mkdir /home/appo/node$i

    # Load the CustomeGenesis file
    gubiq --datadir /home/appo/node$i init /tmp/CustomGenesis.json

    # Create a new account/wallet
    echo second > /home/appo/node$i/passwd.file
    gubiq --datadir /home/appo/node$i/ --password /home/appo/node$i/passwd.file account new > /home/appo/node$i/wallet

    # Get the enode from console and drop out of console
    gubiq --rpc --datadir /home/appo/node$i/ --networkid $n console >& /tmp/node$i.output

    # Inject the IP Adress into the enode string
    enode=`cat /tmp/node$i.output | grep enode | awk '{print $5}'| sed "s/\[::\]/$nodeIP/g"`

    # Write the enode info to the node directory
    echo $enode >> /home/appo/node$i/enode

    # Create the static nodes file

        if [ -f "/tmp/static-nodes.json" ]; then
        ## ------------------------------------#
        cat >> /tmp/static-nodes.json <<EOL
        "$enode",
EOL
        ## ------------------------------------#
        else
        ## ------------------------------------#
        echo "[" > /tmp/static-nodes.json
        cat >> /tmp/static-nodes.json <<EOL
        "$enode",
EOL

fi

(( i++ ))
done

# Send the closing bracket "]" to static nodes file
sed -i '$s/\",/\"/g' /tmp/static-nodes.json
echo "]" >> /tmp/static-nodes.json

# Download Net Intelligence API
#if [ -d /home/appo/ubiq-net-intelligence-api ]; then
   #echo "ubiq-net-intelligence-api already installed"
#else
   #cd /home/appo/
   #git clone https://github.com/ubiq/ubiq-net-intelligence-api
   #wait
#fi


# Copy static nodes to each node directory
one=1

while [ "$one" -le "$count" ]; do
   #cp -r /home/appo/ubiq-net-intelligence-api /home/appo/node$one
   cp /tmp/static-nodes.json /home/appo/node$one
   cp -R /home/appo/gubiq/ubiq-net-intelligence-api/ /home/appo/node$one
   cd /home/appo/node$one/ubiq-net-intelligence-api/
   sed -i 's/INSTANCE_NAME= ""//INSTANCE_NAME=node$one' app.json
   (( one++ ))
done

e=1
# Copy datadir to each peer node
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
  # Copy the Node directories to the respective nodes
  expect_password "scp -p -o StrictHostKeyChecking=no -r /home/appo/node$e appo@node$e:/home/appo"

  # Starting tmux on every node
  expect_password "ssh -t -o StrictHostKeyChecking=no node$e tmux new -s whiteblock -d"

  # Starting console in tmux on every node
  expect_password "ssh -t -o StrictHostKeyChecking=no node$e tmux send-keys -t whiteblock 'gubiq\ --datadir\ /home/appo/node$e\ --networkid\ 17835\ --rpc\ console' C-m"

  # Edit the app.json file for Netstats
  expect_password "ssh -t -o StrictHostKeyChecking=no node$e sed -i 's/\"INSTANCE_NAME\".*/\"INSTANCE_NAME\"\\t\:\ \"node$e\",/g'\ $(find\ ./\ -type\ d\ -name\ /ubiq-net-intelligence-api)/app.json"
  expect_password "ssh -t -o StrictHostKeyChecking=no node$e \"sed -i 's/\\\"WS_SERVER\\\".*/\\\"WS_SERVER\\\"\: \\\"http:\/\/192.168.168.231\:3000\\\",/g' $(find ./ -type d -name ubiq-net-intelligence-api)/app.json\""
  #Change the WS SERVER in app.json on all nodes
  #expect_password "ssh -t -o StrictHostKeyChecking=no node$e sed -i 's/\"WS_SERVER\".*/\"WS_SERVER\"\t\:\ \"http:\/\/192.168.168.231\:3000\",/g'\ $(find\ ./\ -type\ d\ -name\ ubiq-net-intelligence-api)/app.json"

  #Chang the WS_SECRET in app.json on all nodes
  expect_password "ssh -t -o StrictHostKeyChecking=no node$e sed -i 's/\"WS_SECRET\".*/\"WS_SECRET\"\t\:\ \"second\",/g'\ $(find\ ./\ -type\ d\ -name\ ubiq-net-intelligence-api)/app.json"

  #Start the net inteligence API on all nodes
  expect_password "ssh -t -o StrictHostKeyChecking=no node$e cd /home/appo/gubiq/ubiq-net-intelligence-api && pm2 start app.json"

(( e++ ))
done
