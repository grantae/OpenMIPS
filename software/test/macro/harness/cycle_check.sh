#!/usr/bin/env bash
#
# Given a maximum expected cycle count, an actual cycle count, and an output file name,
# write '0' to the output if the expected cycle count is less than the actual count,
# otherwise do not modify the output file.
#
# Author: Grant Ayers
#
if [ -e $1 ] ; then
    if [ ! -e $2 ] ; then
        echo "Cannot find cycle count file '$2'"
        echo "0" > $3
        exit
    fi
    MAX_CYCLES=$(< $1)
    TST_CYCLES=$(< $2)
    TST_RESULT=$3
    if [[ "$MAX_CYCLES" -lt "$TST_CYCLES" ]] ; then
        echo "0" > $TST_RESULT
    fi
fi
