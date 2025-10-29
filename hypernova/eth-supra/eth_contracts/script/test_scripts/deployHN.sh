#!/bin/bash
source ../../.env
forge script DeployHN.s.sol:DeployHNScript \
    --rpc-url $SRC_RPC_URL \
    --broadcast \
    --legacy \
    --via-ir \
    -vvvvv
