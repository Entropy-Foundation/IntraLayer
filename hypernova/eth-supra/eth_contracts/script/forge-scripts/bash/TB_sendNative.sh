#!/bin/bash
source ../../../.env
forge script ../TB_sendNative.s.sol:TBsendNative \
    --rpc-url $SRC_RPC_URL \
    --private-key $USER_PRIVATE_KEY \
    --broadcast \
    --via-ir \
    -vvvvv
