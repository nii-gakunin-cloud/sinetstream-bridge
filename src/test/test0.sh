#!/bin/sh

. ./subr.sh

set -eux

TEST_INIT

./gen_config.sh \
    "upstream-1/mqtt/broker_mqtt_1/topic-mqtt-1" \
    "downstream-1/kafka/broker_kafka_1/topic-kafka-1" \
    >tmp/.sinetstream_config.yml

TEST_PING upstream-1 upstream-1
TEST_PING downstream-1 downstream-1

TEST_INIT_BRIDGE mybridge

TEST_PING upstream-1 downstream-1
