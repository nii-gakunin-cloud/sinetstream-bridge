#!/bin/sh

. ./subr.sh

set -eux

TEST_INIT

TEST1() {
    local READERS
    local WRITERS
    READERS="$1"
    WRITERS="$2"
    ./gen_config.sh "$READERS" "$WRITERS" >tmp/.sinetstream_config.yml
    TEST_INIT_BRIDGE mybridge

    ## test for brokers
    #for X in $READERS $WRITERS; do
    #    SVC="$(echo "$X" | cut -d/ -f1)"
    #    TEST_PING "$SVC" "$SVC"
    #    printf "*** OK: %s -> %s\n" "$SVC" "$SVC"
    #done

    # test for bridge
    for R in $READERS; do
        for W in $WRITERS; do
            RSVC="$(echo "$R" | cut -d/ -f1)"
            WSVC="$(echo "$W" | cut -d/ -f1)"
            TEST_PING "$RSVC" "$WSVC"
            printf "*** RESULT: OK: %s -> %s\n" "$RSVC" "$WSVC"
        done
    done

    TEST_FINI_BRIDGE
}

UPSTREAM1="upstream-1/mqtt/broker_mqtt_1/topic-mqtt-1"
UPSTREAM2="upstream-2/mqtt/broker_mqtt_2/topic-mqtt-2 $UPSTREAM1"
UPSTREAM3="upstream-3/mqtt/broker_mqtt_3/topic-mqtt-3 $UPSTREAM2"

DOWNSTREAM1="downstream-1/kafka/broker_kafka_1/topic-kafka-1"
DOWNSTREAM2="downstream-2/kafka/broker_kafka_2/topic-kafka-2 $DOWNSTREAM1"
DOWNSTREAM3="downstream-3/kafka/broker_kafka_3/topic-kafka-3 $DOWNSTREAM2"

TEST1 "$UPSTREAM1" "$DOWNSTREAM1"
TEST1 "$UPSTREAM1" "$DOWNSTREAM2"
TEST1 "$UPSTREAM1" "$DOWNSTREAM3"

TEST1 "$UPSTREAM2" "$DOWNSTREAM1"
TEST1 "$UPSTREAM3" "$DOWNSTREAM1"

TEST1 "$UPSTREAM3" "$DOWNSTREAM3"
