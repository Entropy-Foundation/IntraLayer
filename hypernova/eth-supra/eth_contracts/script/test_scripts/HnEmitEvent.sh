#!/bin/bash
source ../../.env
forge script HNEmitEvent.s.sol:HNEmitEvent \
    --rpc-url $SRC_RPC_URL \
    --broadcast \
    --via-ir \
    --private-key $USER_PRIVATE_KEY\
    -vvvvv
