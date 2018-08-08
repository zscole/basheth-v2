#!/bin/bash

rm -rf /home/appo/node* && rm /tmp/static-nodes.json && rm -f /tmp/all_wallet
pkill -f tmux

c=17835
n=17835
g=4000000
b=0x03D0900
N=3

function usage {
		cat <<EOM
	 Usage: build -b <genesis gas limit> -g <gaslimit> -c <chainId> -n <networkid> -N <Number of nodes> 
	 Example: build -b 0x03D0900 -g 4000000 -c 17835 -n 17835 -N 12
EOM
	exit 1
}

while getopts "b:g:c:n:N:h" optKey; do
	case $optKey in
		b) 
			b=$OPTARG
		    	;;
		c)
			c=$OPTARG
			;;
		n)
			n=$OPTARG
			;;
		N)
			N=$OPTARG
			;;
		g)
			g=$OPTARG
			;;
		h|*)
			usage
			;;
	esac
done

i=1
while [ "$i" -le "$N" ]; do
    echo "---------------------  CREATING accounts for NODE-$i  ---------------------"
	# Create the node directory
	mkdir /home/appo/node$i
	# Create a new account/wallet
	for addline in {1..35}; do
	 	echo second >> /home/appo/node$i/passwd.file
	done
	gubiq --datadir /home/appo/node$i/ --password /home/appo/node$i/passwd.file account new | awk '{print $2}' | sed -E 's/\{|\}//g' > /home/appo/node$i/wallet
	(( i++ ))
done

# gathering all wallets into one file
for wall in `find /home/appo/node*/ -type f -name wallet`; do
  	wallet=`cat $wall`
  	echo -e "$wallet" >> /tmp/all_wallet
done

#Adding money to all wallets
alloc=`cat /tmp/all_wallet | sed -e 's/^/"/' | sed -e 's/$/": \{\"balance\"\: \"100000000000000000000\"\},/' | sed '$ s/.$//'`
unlock=`cat /tmp/all_wallet | sed -e ':a;N;$!ba;s/\n/,/g'`

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
	"gasLimit": "$b",
	"alloc": {
$alloc
 }
}
EOF

i=1
while [ "$i" -le "$N" ]; do
	echo "---------------------  INITIALIZING NODE-$i  ---------------------"
	# set the ip address for the enode
	nodeIP=10.$i.100.100
	# Load the CustomeGenesis file
	gubiq --datadir /home/appo/node$i init /tmp/CustomGenesis.json
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

one=1
while [ "$one" -le "$N" ]; do
# Copy static nodes to each node directory
   	cp /tmp/static-nodes.json /home/appo/node$one
   	(( one++ ))
done

#  Copy all UTC keystore files to every Node directory
ct=1
while [ "$ct" -le "$N" ]; do
    echo "---------------------  TRANSFERRING accounts for NODE-$i  ---------------------"
   	for LINE in `find /home/appo/node*/ -type f -name UTC* | grep -v node$ct`
   	do
	 	cp $LINE /home/appo/node$ct/keystore
	done
	(( ct++ ))
done

# Somehow UTC are not copied to node 1 correctly so do it again here specific for node1
for LINE in `find /home/appo/node*/ -type f -name UTC* | grep -v UTC`
do
	cp $LINE /home/appo/node1/keystore
done

# Data dir to each node 
e=1
while [ $e -le $N ] ; do
echo "---------------------  SCP data dir to node$e ---------------------"
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
    expect_password "ssh -t -o StrictHostKeyChecking=no node$e rm -Rf /home/appo/node$e"
	expect_password "scp -p -o StrictHostKeyChecking=no -r /home/appo/node$e appo@node$e:/home/appo"
  	expect_password "ssh -t -o StrictHostKeyChecking=no node$e pkill -f tmux"
	expect_password "ssh -t -o StrictHostKeyChecking=no node$e tmux new -s whiteblock -d"
	expect_password "ssh -t -o StrictHostKeyChecking=no node$e tmux send-keys -t whiteblock 'gubiq\ --datadir\ /home/appo/node$e\ --nodiscover\ --maxpeers\ 50\ --targetgaslimit\ $g\ --networkid\ $n\ --rpc\ --mine --unlock \\\"$unlock\\\" --password /home/appo/node$e/passwd.file --etherbase `cat /home/appo/node$e/wallet` console' C-m"
	expect_password "ssh -t -o StrictHostKeyChecking=no node$e tmux new -s pm2 -d"
    expect_password "ssh -t -o StrictHostKeyChecking=no node$e tmux send-keys -t pm2 'cd /home/appo/ubiq-net-intelligence-api && pm2 start app.json' C-m"
	(( e++ ))
done


echo "---------------------  PREPARING node 1 ---------------------"
tmux new -s netstats -d
tmux send-keys -t netstats 'cd /home/appo/gubiq/eth-netstats' C-m
tmux send-keys -t netstats 'WS_SECRET=second npm start' C-m
tmux new -s pm2 -d
tmux send-keys -t pm2 'cd /home/appo/gubiq-net-intelligence-api && pm2 start app.json'
echo "---------------------  READY FOR ACTION ---------------------"

exit
