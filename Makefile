DISTFILES := bugzy.cfg bugzy.sh
VERSION := 0.1
 
DISTNAME=bugzy.txt-$(VERSION)
dist: $(DISTFILES) bugzy.sh
	mkdir -p $(DISTNAME)
	cp -f $(DISTFILES) $(DISTNAME)/
	#sed -e 's/@DEV_VERSION@/'$(VERSION)'/' bugzy.sh > $(DISTNAME)/bugzy.sh
	tar cf $(DISTNAME).tar $(DISTNAME)/
	gzip -f -9 $(DISTNAME).tar
	zip -9r $(DISTNAME).zip $(DISTNAME)/
	rm -r $(DISTNAME)
 
.PHONY: clean
clean:
	rm -f $(DISTNAME).tar.gz $(DISTNAME).zip

INSTALL_DIR=/opt/local/bin

install:
	cp -i bugzy.cfg ~/
	chmod +x bugzy.sh
	cp bugzy.sh $(INSTALL_DIR)
