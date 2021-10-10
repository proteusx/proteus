SHELL = /bin/bash
TEX_FILE = proteus-gr-09
TEX = latexmk
DOC_DIR = ../../../doc

FLAGS = -xelatex

all: $(TEX_FILE).tex
	$(TEX) $(FLAGS) $^
	install -m 0644 $(TEX_FILE).pdf $(DOC_DIR)
	-rm -f $(TEX_FILE).{aux,toc,fls,log,fdb_latexmk,xdv,pdf}


