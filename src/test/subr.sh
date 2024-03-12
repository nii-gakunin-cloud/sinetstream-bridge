#!/bin/sh

set -eu

TESTDIR=/sinetstream-bridge/src/test  # $PWD is mounted to $TESTDIR in container 'bridge'

#CLI=sinetstream_cli
CLI=$TESTDIR/sinetstream_cli2.py

DOCKERCOMPOSE() {
    #(cd docker && docker compose "$@")
    docker compose --file docker/docker-compose.yml "$@"
}

GET_IPADDR() {
    awk '/hostname:/{HN=$2};/ipv4_address/{print HN,$2}' docker/docker-compose.yml | grep "^$1 " | cut -d' ' -f2
}

ECHON() {
    printf "%s" "$*"
}

TEST_INIT() {
UP_ARGS="${*:-}"

# scratch dir
rm -rf tmp.old
! test -d tmp || mv tmp tmp.old
mkdir -p tmp

# start containers
#DOCKERCOMPOSE down bridge
DOCKERCOMPOSE exec --no-TTY bridge kill 1 || true
${test_dont_docker_down-false} || DOCKERCOMPOSE down
DOCKERCOMPOSE up --detach ${UP_ARGS}
DOCKERCOMPOSE ps

# wait for broker ready
# note: pip install --user yq
local SERVICES
SERVICES=$(yq -r '.services|keys|.[]' docker/docker-compose.yml | grep broker_)
for SERVICE in $SERVICES; do
    case "$SERVICE" in
    *kafka*)
        DOCKERCOMPOSE exec --no-TTY "$SERVICE" /bin/sh -x -c "while ! grep 'Kafka Server started' logs/server.log*; do sleep 1; done"
        printf "XXX %s is UP\n" "$SERVICE"
        ;;
    *mqtt*)
        DOCKERCOMPOSE exec --no-TTY "$SERVICE" /bin/sh -x -c "while ! grep 'mosquitto version .* running' /mosquitto/log/mosquitto.log; do sleep 1; done"
        printf "XXX %s is UP\n" "$SERVICE"
        ;;
    esac
done

} # END TEST_INIT

TEST_REUP() {
DOCKERCOMPOSE up --detach ${UP_ARGS}
}

BRIDGE_MSG_STARTED=""

TEST_INIT_BRIDGE() {
local BRIDGENAME COUNTMAX COUNT
BRIDGENAME=$1; shift
COUNTMAX=${1:-9999}
COUNT=0

local BRIDGE_ARGS
BRIDGE_ARGS="--config-file $TESTDIR/tmp/.sinetstream_config.yml --log-prop-file $TESTDIR/tmp/debug-log.prop ${EXTRA_BRIDGE_ARGS:-}"

DIST_TAR=$(cd ../.. && echo build/distributions/sinetstream-bridge-*.tar)
DOCKERCOMPOSE exec --no-TTY bridge tar --extract --file "$DIST_TAR" --strip-components=1 --directory=/opt
cp ../../src/main/resources/jp/ad/sinet/stream/bridge/debug-log.prop tmp/debug-log.prop
DOCKERCOMPOSE exec --no-TTY bridge rm -f "$TESTDIR/tmp/bridge.out"

cat >tmp/start-bridge.sh <<__END__
#!/bin/sh
exec /opt/bin/sinetstream-bridge $BRIDGE_ARGS >$TESTDIR/tmp/bridge.out 2>&1
__END__
chmod a+x tmp/start-bridge.sh

DOCKERCOMPOSE exec --no-TTY bridge daemon --pidfile="$TESTDIR/tmp/bridge.pid" -- /bin/sh $TESTDIR/tmp/start-bridge.sh
# wait for bridge ready
while ! grep "SINETStream-Bridge:$BRIDGENAME: STARTED" tmp/bridge.out; do
    if [ $COUNT -lt $COUNTMAX ]; then
        sleep 1
        COUNT=$((COUNT + 1))
    else
        printf "XXX BRIDGE is no UP (timeedout)\n"
        return 1
    fi
    if ! DOCKERCOMPOSE exec --no-TTY bridge ps -p $(cat tmp/bridge.pid) >/dev/null; then
        printf "XXX BRIDGE is DEAD\n"
        return 1
    fi
done
printf "XXX BRIDGE is UP\n"
return 0

} # END TEST_INIT_BRIDGE

TEST_FINI_BRIDGE() {
DOCKERCOMPOSE exec --no-TTY bridge pkill java || true # XXX
sleep 1  # XXX
}

TEST_FINI() {

${test_dont_docker_down-false} || DOCKERCOMPOSE down || true

} # END TEST_FINI

TEST_CHECK() {

local RES=0
"$@" || RES=$?
if [ $RES -eq 0 ]; then
    echo "*** OK ***"
else
    echo "*** NG ***"
fi

} # END TEST_CHECK

GEN_RANDOM() {
    dd if=/dev/urandom bs=${1:-32} count=1 status=none | base64 --wrap 0
}

TEST_PING() {
    local SERVICE_IN SERVICE_OUT
    SERVICE_IN="$1"; shift
    SERVICE_OUT="$1"; shift
    local RANDTEXT
    local PID_READER
    RANDTEXT="$(GEN_RANDOM 32)"
    DOCKERCOMPOSE exec --no-TTY --workdir $TESTDIR/tmp bridge $CLI read --service $SERVICE_OUT --raw --text --count 1 >tmp/read.out 2>tmp/read.err &
    PID_READER=$!
    # wait for reader ready
    while ! grep READY tmp/read.err; do
        if ! ps -p "$PID_READER"; then
            echo "ERROR: sinetstream_cli is dead"
            return 1
        fi
        sleep 1
    done
    #sleep 3 # XXX uum settling time for broker ?
    sleep 1 # XXX uum settling time for broker ?
    ECHON "$RANDTEXT" | DOCKERCOMPOSE exec --no-TTY --workdir $TESTDIR/tmp bridge $CLI write --service $SERVICE_IN --text
    wait $PID_READER || true
    TEST_CHECK test "$RANDTEXT" = "$(cat tmp/read.out)"
    sleep 1 # XXX uum settling time for broker ?
}
