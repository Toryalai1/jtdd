#!/bin/bash

OTHER=
SCENE=
eval `jtcfgstr -core kunio -output bash`

while [ $# -gt 0 ]; do
    case "$1" in
        -s)
            shift
            SCENE=$1;;
        *) OTHER="$OTHER $1"
    esac
    shift
done

if [ -n "$SCENE" ]; then
    OTHER="$OTHER -d NOMAIN -nosnd -video 2"
    if [ ! -d $SCENE ]; then
        echo "Error: scene folder $SCENE does not exist"
        exit 1
    fi
    drop1    < $SCENE/char.bin > char_hi.bin
    drop1 -l < $SCENE/char.bin > char_lo.bin
    dd if=$SCENE/scr.bin of=scr_lo.bin count=2
    dd if=$SCENE/scr.bin of=scr_hi.bin count=2 skip=2
    cp $SCENE/pal.bin .
fi

if [ ! -e rom.bin ]; then
    ln -s $ROM/renegdeb.rom rom.bin || exit $?
fi

jtsim -mist -sysname kunio $OTHER
