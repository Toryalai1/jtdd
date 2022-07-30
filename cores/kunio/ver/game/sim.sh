#!/bin/bash

eval `jtcfgstr -core kunio -output bash`

if [ ! -e rom.bin ]; then
    ln -s $ROM/renegdeb.rom rom.bin || exit $?
fi

jtsim -mist -sysname kunio $*
