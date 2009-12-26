DISTFILES := bugzy.cfg README.markdown 
#VERSION := 0.1.3
VERSION := `cat VERSION_FILE`
 
all: install

DISTNAME=bugzy.txt-$(VERSION)
dist: $(DISTFILES) bugzy.sh
	echo "ver: $(VERSION)"
	mkdir -p $(DISTNAME)
	mkdir -p $(DISTNAME)/addons
	mkdir -p $(DISTNAME)/.todos
	cp -f $(DISTFILES) $(DISTNAME)/
	cp todo.txt done.txt $(DISTNAME)/
	cp -f addons/* $(DISTNAME)/addons
	cp -f .todos/*.tsv $(DISTNAME)/.todos
	sed -e 's/@REVISION@/'$(VERSION)'/' bugzy.sh > $(DISTNAME)/bugzy.sh
	tar cf $(DISTNAME).tar $(DISTNAME)/
	gzip -f -9 $(DISTNAME).tar
	zip -9r $(DISTNAME).zip $(DISTNAME)/
	rm -r $(DISTNAME)

.PHONY: clean
clean:
	rm -f $(DISTNAME).tar.gz $(DISTNAME).zip

INSTALL_DIR=~/bin
ACTIONS_DIR=~/.bugzy.actions.d

install:
	#[ bugzy.cgf -nt ~/bugzy.cfg ] && cp -i bugzy.cfg ~/
	## updating cfg
	#cp -uvp bugzy.cfg ~/
	## updating addons
	cp -uvp ./addons/* $(ACTIONS_DIR)
	chmod +x $(ACTIONS_DIR)/*

	## updating bugzy
	cp bugzy.sh $(INSTALL_DIR)/bugzy
	chmod +x $(INSTALL_DIR)/bugzy
