#!/bin/sh

echo "Connecting robot"
ssh -X -C darwin@192.168.123.$1
