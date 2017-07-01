#!/bin/sh
if [ -f ./fabric.keys ]; then
    ./Fabric.framework/run `cat fabric.keys`
fi