SHALL = /bin/bash
TEX_FILE = proteus-en-09
TEX = latexmk
DOC_DIR = ../../../doc

FLAGS = -pdf

all: $(TEX_FILE).tex
	$(TEX) $(FLAGS) $^
	install -m 0644 $(TEX_FILE).pdf $(DOC_DIR)
	-rm $(TEX_FILE).{aux,toc,fls,log,fdb_latexmk,pdf}


