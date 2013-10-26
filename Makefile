# Base directory for I-D
ID_BASE = .

saxpath = "/usr/local/share/saxon-b/saxon9.jar"
saxon = java -classpath $(saxpath) net.sf.saxon.Transform -novw -l
stylesheet = "$(ID_BASE)/tools/rfc2629xslt/rfc2629.xslt"
xml2rfc = "$(ID_BASE)/tools/xml2rfc/xml2rfc.tcl"
rfc2629dir = "tools\\/rfc2629xslt\\/"

NAME = grigorik
TITLE = ${NAME}-$(shell basename ${CURDIR})
#LATEST = $(shell (ls draft-${TITLE}-*.xml || echo "draft-${TITLE}-01.xml") | sort | tail -1)
#VERSION = $(shell basename ${LATEST} .xml | awk -F- '{print $$NF}')
VERSION = 01

TARGET_XML = draft-$(TITLE)-$(VERSION).xml
PREV_TXT = draft-$(TITLE)-$(shell printf "%.2d" `echo ${VERSION}-1 | bc`).txt
NEXT_XML = draft-$(TITLE)-$(shell printf "%.2d" `echo ${VERSION}+1 | bc`).xml

TARGET_HTML = $(TARGET_XML:.xml=.html)
TARGET_TXT = $(TARGET_XML:.xml=.txt)
TARGETS = $(TARGET_HTML) \
          $(TARGET_TXT)

.PHONY: all
all: $(TARGETS)

.PHONY: clean
clean:
	rm -f $(TARGETS)

.PHONY: next
next:
	cp $(TARGET_XML) $(NEXT_XML)

.PHONY: diff
diff:
	rfcdiff $(PREV_TXT) $(TARGET_TXT)

.PHONY: idnits
idnits: $(TARGET_TXT)
	idnits $<

%.html: %.xml
	$(saxon) $< $(stylesheet) > $@

%.txt: %.xml
	$(xml2rfc) $< $@

.PHONY: kramdown
kramdown: draft.md
	kramdown-rfc2629 draft.md > $(TARGET_XML)
	xmllint --format $(TARGET_XML) > tmp
	mv tmp $(TARGET_XML)
	sed -i '' -e"s/rfc2629\.xslt/$(rfc2629dir)rfc2629.xslt/" $(TARGET_XML)
	sed -i '' -e"s/rfc2629\.dtd/$(rfc2629dir)rfc2629.dtd/" $(TARGET_XML)
	cat $(TARGET_XML) | perl -pe "s/<figure anchor=\"[^\"]+\">/<figure>/g" > tmp
	mv tmp $(TARGET_XML)

update:
	make kramdown
	make
