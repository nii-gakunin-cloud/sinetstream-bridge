DIR=docker

all::

extract::
	DIST_TAR=`cd ../.. && echo build/distributions/sinetstream-bridge-*.tar`; \
	docker compose --file docker/docker-compose.yml exec --no-TTY bridge tar --extract --file "$$DIST_TAR" --strip-components=1 --directory=/opt

build up down ps::
	cd $(DIR) && docker compose $@

sh shell::
	cd $(DIR) && docker compose exec bridge /bin/bash
ush ushell::
	cd $(DIR) && docker compose exec --user `id -u` bridge /bin/bash


tests::
	-mv -f test.log test.log.bak
	ls ./test-*.sh | xargs -t -n1 sh 2>&1 | tee test.log
results::
	grep RESULT: test.log | grep -v printf

