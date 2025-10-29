#!/bin/bash
source ../../../.env
forge script ../DeployAndSetupTB.s.sol:DeployAndSetupTB \
    --rpc-url $SRC_RPC_URL \
    --private-key $ADMIN_PRIVATE_KEY \
    --priority-gas-price 20 \
    --broadcast \
    --legacy \
    --via-ir \
    -vvvvv