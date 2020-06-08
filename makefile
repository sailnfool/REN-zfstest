SHELL=/bin/bash
PREFIX?=$(HOME)
PREFIX2?=/tftpboot/global/novak5
.sh:
	@rm -f $@
	cp $< $@
INSTALL = build-tank setup-intree test-intree zdb-hist fill-tank \
	  drain-tank

EXECDIR2=$(PREFIX2)/bin
EXECDIR := $(PREFIX)/bin

.PHONY: clean uninstall all
all: $(INSTALL)
	make uninstall install clean
install: $(INSTALL)
	mkdir -p $(EXECDIR)
	install -o $(USER) -C $? $(EXECDIR)
jetinstall: $(INSTALL)
	mkdir -p $(EXECDIR2)
	install -o $(USER) -C $? $(EXECDIR2)
clean: 
	@for execfile in $(INSTALL); do \
		echo rm -f $$execfile; \
		rm -f $$execfile; \
	done
uninstall: 
	@for execfile in $(INSTALL); do \
		echo rm -f $(EXECDIR)/$$execfile; \
		rm -f $(EXECDIR)/$$execfile; \
	done
$(EXECDIR):
	mkdir -p $(EXECDIR)

