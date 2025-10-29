#!/bin/bash
echo "Starting source chain : http://127.0.0.1:8000"
anvil -p 8000 --chain-id 1 --disable-code-size-limit
