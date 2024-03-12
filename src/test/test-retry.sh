#!/bin/sh

. ./subr.sh

set -eux

TEST_INIT

start_management_reader() {
    local SERVICE="$1"
    rm -f tmp/management.out tmp/management.err
    DOCKERCOMPOSE exec --no-TTY --workdir $TESTDIR/tmp bridge $CLI read --service "$SERVICE" --raw --text >tmp/management.out 2>tmp/management.err &
    PID_MANAGEMENT=$!
# wait for reader ready
    while ! grep READY tmp/management.err; do
        if ! ps -p "$PID_MANAGEMENT"; then
            echo "ERROR: sinetstream_cli is dead"
            return 1
        fi
        sleep 1
    done
}

TEST1() {
cat >tmp/.sinetstream_config.yml

start_management_reader management-1

TEST_INIT_BRIDGE mybridge

TEST_PING upstream-1 downstream-1

kill $PID_MANAGEMENT
wait $PID_MANAGEMENT
}

TEST1 <<__END__
header:
    version: 2
config:
    mybridge:
        type: bridge
        bridge:
            reader: [ upstream-1 ]
            writer: [ downstream-1 ]
    upstream-1:
        value_type: text
        type: mqtt
        brokers: broker_mqtt_1
        topic: topic-mqtt-1
        consistency: AT_LEAST_ONCE
        debugBridgeFailureRate: 3
    downstream-1:
        value_type: text
        type: kafka
        brokers: broker_kafka_1
        topic: topic-kafka-1
        consistency: AT_LEAST_ONCE
__END__

TEST_FINI

exit 0
