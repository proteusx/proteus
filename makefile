SHELL = /bin/bash
#------------------------------------------------------
# Install directories
# Edit INSTALL_PREFIX if want to install somewhere else
#------------------------------------------------------

INSTALL_PREFIX=/usr/local
INSTALL_DIR=$(INSTALL_PREFIX)/proteus
BIN_DIR=$(INSTALL_DIR)/bin
CANONS_DIR=$(INSTALL_DIR)/canons
ICONS_DIR=$(INSTALL_DIR)/icons
FONTS_DIR=$(INSTALL_PREFIX)/share/fonts
CDROM_DIR=$(INSTALL_PREFIX)/CDROMS
APPLICATIONS=/usr/share/applications
SYSTEM_ICON_DIR =/usr/share/pixmaps

#------------------------------------------------------
.PHONY: install uninstall test_xetex test_perl bins docs clean fonts

all: canon docs

install:
	install -d $(BIN_DIR) $(CANONS_DIR) $(ICONS_DIR) $(FONTS_DIR)
	install -m 0755 proteus.pl $(INSTALL_DIR)
	install -m 0644 sample.dat test.tex proteusrc escape_codes.tex $(INSTALL_DIR)
	install -m 0644 ./canons/* $(CANONS_DIR)
	install -m 0755 ./bin/* $(BIN_DIR)
	install -m 0644 ./icons/* $(ICONS_DIR)
	install -m 0644 ./proteus.desktop $(APPLICATIONS)
	install -m 0644 ./icons/proteus.png $(SYSTEM_ICON_DIR)
	install -m 0644 ./icons/Book.png $(SYSTEM_ICON_DIR)
	ln -sf $(INSTALL_DIR)/proteus.pl $(INSTALL_PREFIX)/bin/proteus

uninstall:
	-rm -rf $(INSTALL_DIR)
	-rm $(INSTALL_PREFIX)/bin/proteus
	-rm $(APPLICATIONS)/proteus.desktop
	-rm $(SYSTEM_ICON_DIR)/proteus.png
	-rm $(SYSTEM_ICON_DIR)/Book.png

test_xetex:
	@./xetex_test.sh

test_perl:
	@./perl_test.sh

fonts:
	install -m 0644 ./fonts/* $(FONTS_DIR)
	fc-cache -f -v &> /dev/null


bins:
	install -d ./bin
	$(MAKE) -C ./src/tlg2u/src
	$(MAKE) -C ./src/read_idt

canon: bins
	@cd ./canons; ./make-canon.pl

docs:
	install -d ./doc
	$(MAKE) -C ./src/tlg2u/src docs
	$(MAKE) -C ./src/manual/en
	$(MAKE) -C ./src/manual/gr

# Delete binaries, object files and pdfs for upload
clean:
	-rm -rf ./bin ./doc
	-rm ./canons/canons
	-rm ./src/tlg2u/src/*.{o,d}

