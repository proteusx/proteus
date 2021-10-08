
CC = gcc
CFLAGS = -march=core2 -O2 -pipe -s

EXEC_DIR = ../../bin/
SRC = ./read_idt.c
EXEC = $(EXEC_DIR)read_idt

all: ${SRC}
	$(CC) $(CFLAGS) -o $(EXEC) $^
