#!/bin/bash

function usage {
        cat <<EOM
     Usage: create_block -c <chainId> -n <networkid>
     Example: create_block -c 17835211 -n 178354
EOM
    exit 1
}

while getopts ":c:n:h" optKey; do
    case $optKey in
        c)
            c=$OPTARG
            ;;
	n)
            n=$OPTARG
            ;;
        h|*)
            usage
            ;;
    esac
done

c=696969
n=17835

if [ -f "/tmp/CustomGenesis.json" ]; then
	echo "Genesis file already exists! Do you want to remove it?"
        select yn in "Yes" "No"; do
        case $yn in
            Yes ) rm /tmp/CustomGenesis.json
            No ) exit;;

while true; do
    read -p "Genesis file already exists! Do you want to remove it?" yn
    case $yn in
        [Yy]* ) rm /tmp/CustomGenesis.json; break;;
        [Nn]* ) exit;;
        * ) echo "Yes or no.";;
    esac
done

cat <<EOF > /tmp/CustomGenesis.json
{
    "config": {
        "chainId": $c,
        "homesteadBlock": 0,
        "eip155Block": 0,
        "eip158Block": 0
    },
    "difficulty": "0x4000",
    "gasLimit": "0x2100000",
    "alloc": {}
}
EOF

fi

rm /tmp/static-nodes.json

for i in {1..3}; do

count=$i
# set the ip address for the enode
nodeIP=10.$i.100.100

# Create the node directory
mkdir /home/appo/node$i

# Load the CustomeGenesis file
gubiq --datadir /home/appo/node$i init /tmp/CustomGenesis.json

# Create a new account/wallet
gubiq --password passwd.file account new >> /home/appo/node$i/wallet

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

done

# Close static nodes file
sed -i '$s/\",/\"/g' /tmp/static-nodes.json
echo "]" >> /tmp/static-nodes.json

# Copy static nodes to each node directory
j=1

while [ "$j" -le "$count" ]; do
cp /tmp/static-nodes.json /home/appo/node$j
(( one++ ))
done

# allow ssh 
for i in {1..3}; do
count=$i
ssh-copy-id node$i 
done

# Copy datadir to each peer node
for i in {1..3}; do
count=$i
scp -r /home/appo/node$i node$i:/home/appo
done

expect "appo@node1's password:"
send "w@ntest"
expect "appo@node2's password:"
send "w@ntest"
expect "appo@node3's password:"
send "w@ntest"
done













