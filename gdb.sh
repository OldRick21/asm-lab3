#!/bin/bash
make 
gdb bin -x gdb_script.txt
make clean

