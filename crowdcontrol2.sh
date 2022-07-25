#!/bin/bash

while true
do

# Logo

echo -e '\e[40m\e[91m'
echo -e '  ____                  _                    '
echo -e ' / ___|_ __ _   _ _ __ | |_ ___  _ __        '
echo -e '| |   |  __| | | |  _ \| __/ _ \|  _ \       '
echo -e '| |___| |  | |_| | |_) | || (_) | | | |      '
echo -e ' \____|_|   \__  |  __/ \__\___/|_| |_|      '
echo -e '            |___/|_|                         '
echo -e '    _                 _                      '
echo -e '   / \   ___ __ _  __| | ___ _ __ ___  _   _ '
echo -e '  / _ \ / __/ _  |/ _  |/ _ \  _   _ \| | | |'
echo -e ' / ___ \ (_| (_| | (_| |  __/ | | | | | |_| |'
echo -e '/_/   \_\___\__ _|\__ _|\___|_| |_| |_|\__  |'
echo -e '                                       |___/ '
echo -e '\e[0m'

sleep 2

# Menu

PS3='Select an action: '
options=(
"Install"
"Create Wallet"
"Create Validator"
"Exit")
select opt in "${options[@]}"
do
case $opt in

"Install")
echo "============================================================"
echo "Install start"
echo "============================================================"


# set vars
if [ ! $NODENAME ]; then
	read -p "Enter node name: " NODENAME
	echo 'export NODENAME='$NODENAME >> $HOME/.bash_profile
fi
CARDCHAIN_PORT=18
if [ ! $WALLET ]; then
	echo "export WALLET=wallet" >> $HOME/.bash_profile
fi
echo "export CARDCHAIN_CHAIN_ID=Cardchain" >> $HOME/.bash_profile
echo "export CARDCHAIN_PORT=${CARDCHAIN_PORT}" >> $HOME/.bash_profile
source $HOME/.bash_profile

# update
sudo apt update && sudo apt upgrade -y
sudo apt install curl tar wget clang pkg-config libssl-dev jq build-essential bsdmainutils git make ncdu gcc git jq chrony liblz4-tool -y

# install go
source $HOME/.bash_profile
    if go version > /dev/null 2>&1
    then
        echo -e '\n\e[40m\e[92mSkipped Go installation\e[0m'
    else
        echo -e '\n\e[40m\e[92mStarting Go installation...\e[0m'
        ver="1.18.2"
cd $HOME
wget "https://golang.org/dl/go$ver.linux-amd64.tar.gz"
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf "go$ver.linux-amd64.tar.gz"
rm "go$ver.linux-amd64.tar.gz"
echo "export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin" >> ~/.bash_profile
source ~/.bash_profile
go version
    fi

# download binary
curl https://get.ignite.com/DecentralCardGame/Cardchain@latest! | sudo bash

# config
Cardchain config chain-id $CARDCHAIN_CHAIN_ID
Cardchain config keyring-backend test

# init
Cardchain init $NODENAME --chain-id $CARDCHAIN_CHAIN_ID

# download genesis and addrbook
wget -O $HOME/.Cardchain/config/genesis.json "https://raw.githubusercontent.com/DecentralCardGame/Testnet1/main/genesis.json"
wget -O $HOME/.Cardchain/config/addrbook.json "https://raw.githubusercontent.com/StakeTake/guidecosmos/main/CrowdControl/Cardchain/addrbook.json"

# set minimum gas price
sed -i -e "s/^minimum-gas-prices *=.*/minimum-gas-prices = \"0ubpf\"/" $HOME/.Cardchain/config/app.toml

# set peers and seeds
SEEDS=""
PEERS="a89083b131893ca8a379c9b18028e26fa250473c@159.69.11.174:36656"; \
sed -i.bak -e "s/^seeds *=.*/seeds = \"$SEEDS\"/; s/^persistent_peers *=.*/persistent_peers = \"$PEERS\"/" $HOME/.Cardchain/config/config.toml

# enable prometheus
sed -i -e "s/prometheus = false/prometheus = true/" $HOME/.Cardchain/config/config.toml

# config pruning
indexer="null"
pruning="custom"
pruning_keep_recent="100"
pruning_keep_every="0"
pruning_interval="10"

sed -i -e "s/^indexer *=.*/indexer = \"$indexer\"/" $HOME/.Cardchain/config/config.toml
sed -i -e "s/^pruning *=.*/pruning = \"$pruning\"/" $HOME/.Cardchain/config/app.toml
sed -i -e "s/^pruning-keep-recent *=.*/pruning-keep-recent = \"$pruning_keep_recent\"/" $HOME/.Cardchain/config/app.toml
sed -i -e "s/^pruning-keep-every *=.*/pruning-keep-every = \"$pruning_keep_every\"/" $HOME/.Cardchain/config/app.toml
sed -i -e "s/^pruning-interval *=.*/pruning-interval = \"$pruning_interval\"/" $HOME/.Cardchain/config/app.toml

# reset
Cardchain unsafe-reset-all

# create service
tee $HOME/Cardchain.service > /dev/null <<EOF
[Unit]
Description=teritori
After=network.target
[Service]
Type=simple
User=$USER
ExecStart=$(which Cardchain) start
Restart=on-failure
RestartSec=10
LimitNOFILE=65535
[Install]
WantedBy=multi-user.target
EOF

sudo mv $HOME/Cardchain.service /etc/systemd/system/

# start service
sudo systemctl daemon-reload
sudo systemctl enable Cardchain
sudo systemctl restart Cardchain

break
;;

"Create Wallet")
Cardchain keys add $WALLET
echo "============================================================"
echo "Save address and mnemonic"
echo "============================================================"
CARDCHAIN_WALLET_ADDRESS=$(Cardchain keys show $WALLET -a)
CARDCHAIN_VALOPER_ADDRESS=$(Cardchain keys show $WALLET --bech val -a)
echo 'export CARDCHAIN_WALLET_ADDRESS='${CARDCHAIN_WALLET_ADDRESS} >> $HOME/.bash_profile
echo 'export CARDCHAIN_VALOPER_ADDRESS='${CARDCHAIN_VALOPER_ADDRESS} >> $HOME/.bash_profile
source $HOME/.bash_profile

break
;;

"Create Validator")
Cardchain tx staking create-validator \
  --amount 1000000ubpf \
  --from $WALLETNAME \
  --commission-max-change-rate "0.05" \
  --commission-max-rate "0.20" \
  --commission-rate "0.05" \
  --min-self-delegation "1" \
  --pubkey $(Cardchain tendermint show-validator) \
  --moniker $NODENAME \
  --chain-id $CARDCHAIN_CHAIN_ID \
  --gas 300000 \
  -y
  
break
;;

"Exit")
exit
;;
*) echo "invalid option $REPLY";;
esac
done
done
