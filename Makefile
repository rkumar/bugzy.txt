DISTFILES := bugzy.cfg README.markdown
VERSION := 0.1
 
all: install

DISTNAME=bugzy.txt-$(VERSION)
dist: $(DISTFILES) bugzy.sh
	mkdir -p $(DISTNAME)
	cp -f $(DISTFILES) $(DISTNAME)/
	sed -e 's/@REVISION@/'$(VERSION)'/' bugzy.sh > $(DISTNAME)/bugzy.sh
	tar cf $(DISTNAME).tar $(DISTNAME)/
	gzip -f -9 $(DISTNAME).tar
	zip -9r $(DISTNAME).zip $(DISTNAME)/
	rm -r $(DISTNAME)

.PHONY: clean
clean:
	rm -f $(DISTNAME).tar.gz $(DISTNAME).zip

INSTALL_DIR=~/bin

install:
	#cp -i bugzy.cfg ~/
	cp bugzy.sh $(INSTALL_DIR)/bugzy
	chmod +x $(INSTALL_DIR)/bugzy
