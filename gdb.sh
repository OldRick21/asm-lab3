#!/bin/bash
nasm -g -f elf64 src.s -o src.o
ld --static src.o -o bin 
gdb bin -x /home/s1berian_rat/.config/gdb/gdb_script.txt