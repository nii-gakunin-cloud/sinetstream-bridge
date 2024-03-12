tarball = build/distributions/sinetstream-bridge-1.9.0.tar
app = sinetstream-bridge-1.9.0/bin/sinetstream-bridge
sinetstream_java = ../sinetstream-java

all:: build
build:: $(app)
$(app): $(tarball)
	tar xf $(tarball)
$(tarball):: tags libs
	$(MAKE) assemble
assemble::
	./gradlew assemble
libs:: build_java
	mkdir -p libs
	ls -f $(sinetstream_java)/*/build/libs/*.jar | grep -v -e javadoc -e sources | xargs -IX -n1 -t cp --update X libs
build_java::
	cd $(sinetstream_java) && $(MAKE) build
tags::
	-uctags -R src $(sinetstream_java)/*/src/main/java

run::
	$(app) --log-prop-file src/main/resources/jp/ad/sinet/stream/bridge/debug-log.prop

docserve:: # run mkdocs server
	mkdocs serve
docbuild:: # just build
	mkdocs build
# pkg install py39-mkdocs
# pkg install py39-mkdocs-mermaid2-plugin
# pip install --user mkdocs-enumerate-headings-plugin
