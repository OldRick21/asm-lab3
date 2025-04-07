#!/bin/bash
make 
gdb bin -x /home/s1berian_rat/.config/gdb/gdb_script.txt
make clean

