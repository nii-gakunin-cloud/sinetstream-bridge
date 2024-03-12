#!/bin/sh

. ./subr.sh

set -eux

TEST_INIT

./gen_config.sh \
    "upstream-1/mqtt/broker_mqtt_1/topic-mqtt-1" \
    "downstream-1/kafka/broker_kafka_1/topic-kafka-1" \
    "management-1/kafka/broker_kafka_2/topic-kafka-2" \
    >tmp/.sinetstream_config.yml

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

start_management_reader management-1

TEST_INIT_BRIDGE mybridge

TEST_PING upstream-1 downstream-1

kill $PID_MANAGEMENT
wait $PID_MANAGEMENT

#TEST_FINI

exit 0
