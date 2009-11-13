DISTFILES := bugzy.cfg README.markdown
#VERSION := 0.1.3
VERSION := `cat VERSION_FILE`
 
all: install

DISTNAME=bugzy.txt-$(VERSION)
dist: $(DISTFILES) bugzy.sh
	echo "ver: $(VERSION)"
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
	#diff bugzy.cfg ~/bugzy.cfg
	#[ bugzy.cgf -nt ~/bugzy.cfg ] && cp -i bugzy.cfg ~/
	#cp -i bugzy.cfg ~/
	cp -uv bugzy.cfg ~/

	cp bugzy.sh $(INSTALL_DIR)/bugzy
	chmod +x $(INSTALL_DIR)/bugzy
