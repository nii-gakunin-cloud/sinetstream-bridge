#!/bin/sh

. ./subr.sh

set -eux

OK=0
NG=0

#test_dont_docker_down=true
#skip_default=true

TEST_INIT

TEST1() {
    if "${skip-${skip_default-false}}";then
        return 0
    fi
    local ITEM EXPECTED RES
    ITEM="$1"; shift
    EXPECTED="$1"; shift

    cat >tmp/.sinetstream_config.yml

    TEST_INIT_BRIDGE "mybridge" && RES="$?" || RES="$?"
    #grep 'Exception:' tmp/bridge.out || true

    if [ "$RES" = "$EXPECTED" ]; then
        printf "*** RESULT: OK %s\n" "$ITEM"
        OK=$((OK + 1))
    else
        printf "*** RESULT: NG %s: RES=%s != EXPECTED=%s\n" "$ITEM" "$RES" "$EXPECTED"
        NG=$((NG + 1))
    fi
    cat -n tmp/bridge.out

    TEST_FINI_BRIDGE
}

TEST1 "normal" 0 <<__END__
header:
    version: 2
config:
    mybridge:
        type: bridge
        bridge:
            reader:
                - upstream-1
            writer:
                - downstream-1
    upstream-1:
        value_type: text
        type: mqtt
        brokers: broker_mqtt_1
        topic: topic-mqtt-1
    downstream-1:
        value_type: text
        type: kafka
        brokers: broker_kafka_1
        topic: topic-kafka-1
__END__

TEST1 "v3" 1 <<__END__
header:
    version: 3  # NOT SUPPORTED
config:
    mybridge:
        type: bridge
        bridge:
            reader:
                - upstream-1
            writer:
                - downstream-1
    upstream-1:
        value_type: text
        type: mqtt
        brokers: broker_mqtt_1
        topic: topic-mqtt-1
    downstream-1:
        value_type: text
        type: kafka
        brokers: broker_kafka_1
        topic: topic-kafka-1
__END__

TEST1 "two-bridge" 1 <<__END__
header:
    version: 2
config:
    mybridge:
        type: bridge
        bridge:
            reader:
                - upstream-1
            writer:
                - downstream-1
    mybridge2:
        type: bridge
        bridge:
            reader:
                - upstream-1
            writer:
                - downstream-1
    upstream-1:
        value_type: text
        type: mqtt
        brokers: broker_mqtt_1
        topic: topic-mqtt-1
    downstream-1:
        value_type: text
        type: kafka
        brokers: broker_kafka_1
        topic: topic-kafka-1
__END__

TEST1 "ver1-is-not-accepted" 1 <<__END__
mybridge:
    type: bridge
    bridge:
        reader:
            - upstream-1
        writer:
            - downstream-1
upstream-1:
    value_type: text
    type: mqtt
    brokers: broker_mqtt_1
    topic: topic-mqtt-1
downstream-1:
    value_type: text
    type: kafka
    brokers: broker_kafka_1
    topic: topic-kafka-1
__END__

TEST1 "no-bridge" 1 <<__END__
header:
    version: 2
config:
    mybridge:
        type: hogebridge
        bridge:
            reader:
                - upstream-1
            writer:
                - downstream-1
    upstream-1:
        value_type: text
        type: mqtt
        brokers: broker_mqtt_1
        topic: topic-mqtt-1
    downstream-1:
        value_type: text
        type: kafka
        brokers: broker_kafka_1
        topic: topic-kafka-1
__END__

EXTRA_BRIDGE_ARGS="--service yourbridge" \
TEST1 "dangling-bridge" 1 <<__END__
header:
    version: 2
config:
    mybridge:
        type: bridge
        bridge:
            reader:
                - upstream-1
            writer:
                - downstream-1
    upstream-1:
        value_type: text
        type: mqtt
        brokers: broker_mqtt_1
        topic: topic-mqtt-1
    downstream-1:
        value_type: text
        type: kafka
        brokers: broker_kafka_1
        topic: topic-kafka-1
__END__

TEST1 "no-reader" 1 <<__END__
header:
    version: 2
config:
    mybridge:
        type: bridge
        bridge:
            #reader:
            #    - upstream-1
            writer:
                - downstream-1
    upstream-1:
        value_type: text
        type: mqtt
        brokers: broker_mqtt_1
        topic: topic-mqtt-1
    downstream-1:
        value_type: text
        type: kafka
        brokers: broker_kafka_1
        topic: topic-kafka-1
__END__

TEST1 "dangling-reader" 1 <<__END__
header:
    version: 2
config:
    mybridge:
        type: bridge
        bridge:
            reader:
                - upstream-999
            writer:
                - downstream-1
    upstream-1:
        value_type: text
        type: mqtt
        brokers: broker_mqtt_1
        topic: topic-mqtt-1
    downstream-1:
        value_type: text
        type: kafka
        brokers: broker_kafka_1
        topic: topic-kafka-1
__END__

TEST1 "bad-reader" 1 <<__END__
header:
    version: 2
config:
    mybridge:
        type: bridge
        bridge:
            reader:
                - 999
            writer:
                - downstream-1
    999:
        value_type: text
        type: mqtt
        brokers: broker_mqtt_1
        topic: topic-mqtt-1
    downstream-1:
        value_type: text
        type: kafka
        brokers: broker_kafka_1
        topic: topic-kafka-1
__END__

TEST1 "reader-nohost" 1 <<__END__
header:
    version: 2
config:
    mybridge:
        type: bridge
        bridge:
            reader:
                - upstream-1
            writer:
                - downstream-1
    upstream-1:
        value_type: text
        type: mqtt
        brokers: broker_mqtt_999
        topic: topic-mqtt-1
    downstream-1:
        value_type: text
        type: kafka
        brokers: broker_kafka_1
        topic: topic-kafka-1
__END__

TEST1 "no-writer" 1 <<__END__
header:
    version: 2
config:
    mybridge:
        type: bridge
        bridge:
            reader:
                - upstream-1
            #writer:
            #    - downstream-1
    upstream-1:
        value_type: text
        type: mqtt
        brokers: broker_mqtt_1
        topic: topic-mqtt-1
    downstream-1:
        value_type: text
        type: kafka
        brokers: broker_kafka_1
        topic: topic-kafka-1
__END__

TEST1 "dangling-writer" 1 <<__END__
header:
    version: 2
config:
    mybridge:
        type: bridge
        bridge:
            reader:
                - upstream-1
            writer:
                - downstream-999
    upstream-1:
        value_type: text
        type: mqtt
        brokers: broker_mqtt_1
        topic: topic-mqtt-1
    downstream-1:
        value_type: text
        type: kafka
        brokers: broker_kafka_1
        topic: topic-kafka-1
__END__

TEST1 "writer-nohost" 1 <<__END__
header:
    version: 2
config:
    mybridge:
        type: bridge
        bridge:
            reader:
                - upstream-1
            writer:
                - downstream-1
    upstream-1:
        value_type: text
        type: mqtt
        brokers: broker_mqtt_1
        topic: topic-mqtt-1
    downstream-1:
        value_type: text
        type: kafka
        brokers: broker_kafka_999
        topic: topic-kafka-1
__END__

TEST1 "unkown-bridge-param-is-ignored" 0 <<__END__
header:
    version: 2
config:
    mybridge:
        type: bridge
        bridge:
            reader:
                - upstream-1
            writer:
                - downstream-1
        unknown:
            - paramter
    upstream-1:
        value_type: text
        type: mqtt
        brokers: broker_mqtt_1
        topic: topic-mqtt-1
    downstream-1:
        value_type: text
        type: kafka
        brokers: broker_kafka_1
        topic: topic-kafka-1
__END__

TEST1 "valid-max_qlen" 0 <<__END__
header:
    version: 2
config:
    mybridge:
        type: bridge
        bridge:
            reader:
                - upstream-1
            writer:
                - downstream-1
            max_qlen: 99999999
    upstream-1:
        value_type: text
        type: mqtt
        brokers: broker_mqtt_1
        topic: topic-mqtt-1
    downstream-1:
        value_type: text
        type: kafka
        brokers: broker_kafka_1
        topic: topic-kafka-1
__END__

TEST1 "error-max_qlen-1" 1 <<__END__
header:
    version: 2
config:
    mybridge:
        type: bridge
        bridge:
            reader:
                - upstream-1
            writer:
                - downstream-1
            max_qlen: -1
    upstream-1:
        value_type: text
        type: mqtt
        brokers: broker_mqtt_1
        topic: topic-mqtt-1
    downstream-1:
        value_type: text
        type: kafka
        brokers: broker_kafka_1
        topic: topic-kafka-1
__END__

TEST1 "error-max_qlen-str" 1 <<__END__
header:
    version: 2
config:
    mybridge:
        type: bridge
        bridge:
            reader:
                - upstream-1
            writer:
                - downstream-1
            max_qlen: hoge
    upstream-1:
        value_type: text
        type: mqtt
        brokers: broker_mqtt_1
        topic: topic-mqtt-1
    downstream-1:
        value_type: text
        type: kafka
        brokers: broker_kafka_1
        topic: topic-kafka-1
__END__

TEST1 "valid-error_params" 0 <<__END__
header:
    version: 2
config:
    mybridge:
        type: bridge
        bridge:
            reader:
                - upstream-1
            writer:
                - downstream-1
            retry:
                connect_max: 1
                connect_min_delay: 2
                connect_max_delay: 3
            report: management-1
    upstream-1:
        value_type: text
        type: mqtt
        brokers: broker_mqtt_1
        topic: topic-mqtt-1
    downstream-1:
        value_type: text
        type: kafka
        brokers: broker_kafka_1
        topic: topic-kafka-1
    management-1:
        value_type: text
        type: kafka
        brokers: broker_kafka_2
        topic: topic-kafka-2
__END__

TEST1 "bad-report" 1 <<__END__
header:
    version: 2
config:
    mybridge:
        type: bridge
        bridge:
            reader:
                - upstream-1
            writer:
                - downstream-1
            retry:
                connect_max: 1
                connect_min_delay: 2
                connect_max_delay: 3
            report: 999
    upstream-1:
        value_type: text
        type: mqtt
        brokers: broker_mqtt_1
        topic: topic-mqtt-1
    downstream-1:
        value_type: text
        type: kafka
        brokers: broker_kafka_1
        topic: topic-kafka-1
    management-1:
        value_type: text
        type: kafka
        brokers: broker_kafka_2
        topic: topic-kafka-2
__END__

TEST1 "dangling-report" 1 <<__END__
header:
    version: 2
config:
    mybridge:
        type: bridge
        bridge:
            reader:
                - upstream-1
            writer:
                - downstream-1
            retry:
                connect_max: 1
                connect_min_delay: 2
                connect_max_delay: 3
            report: management-999
    upstream-1:
        value_type: text
        type: mqtt
        brokers: broker_mqtt_1
        topic: topic-mqtt-1
    downstream-1:
        value_type: text
        type: kafka
        brokers: broker_kafka_1
        topic: topic-kafka-1
    management-1:
        value_type: text
        type: kafka
        brokers: broker_kafka_2
        topic: topic-kafka-2
__END__

TEST1 "report-nohost" 1 <<__END__
header:
    version: 2
config:
    mybridge:
        type: bridge
        bridge:
            reader:
                - upstream-1
            writer:
                - downstream-1
            retry:
                connect_max: 1
                connect_min_delay: 2
                connect_max_delay: 3
            report: management-1
    upstream-1:
        value_type: text
        type: mqtt
        brokers: broker_mqtt_1
        topic: topic-mqtt-1
    downstream-1:
        value_type: text
        type: kafka
        brokers: broker_kafka_1
        topic: topic-kafka-1
    management-1:
        value_type: text
        type: kafka
        brokers: broker_kafka_9999
        topic: topic-kafka-2
__END__

TEST1 "bad-retry_connect_max" 1 <<__END__
header:
    version: 2
config:
    mybridge:
        type: bridge
        bridge:
            reader:
                - upstream-1
            writer:
                - downstream-1
            retry:
                connect_max: hoge
                connect_min_delay: 2
                connect_max_delay: 3
            report: management-1
    upstream-1:
        value_type: text
        type: mqtt
        brokers: broker_mqtt_1
        topic: topic-mqtt-1
    downstream-1:
        value_type: text
        type: kafka
        brokers: broker_kafka_1
        topic: topic-kafka-1
    management-1:
        value_type: text
        type: kafka
        brokers: broker_kafka_2
        topic: topic-kafka-2
__END__

TEST1 "bad-retry_connect_min_delay" 1 <<__END__
header:
    version: 2
config:
    mybridge:
        type: bridge
        bridge:
            reader:
                - upstream-1
            writer:
                - downstream-1
            retry:
                connect_max: 1
                connect_min_delay: hoge
                connect_max_delay: 3
            report: management-1
    upstream-1:
        value_type: text
        type: mqtt
        brokers: broker_mqtt_1
        topic: topic-mqtt-1
    downstream-1:
        value_type: text
        type: kafka
        brokers: broker_kafka_1
        topic: topic-kafka-1
    management-1:
        value_type: text
        type: kafka
        brokers: broker_kafka_2
        topic: topic-kafka-2
__END__

TEST1 "bad-retry_connect_max_delay" 1 <<__END__
header:
    version: 2
config:
    mybridge:
        type: bridge
        bridge:
            reader:
                - upstream-1
            writer:
                - downstream-1
            retry:
                connect_max: 1
                connect_min_delay: 2
                connect_max_delay: hoge
            report: management-1
    upstream-1:
        value_type: text
        type: mqtt
        brokers: broker_mqtt_1
        topic: topic-mqtt-1
    downstream-1:
        value_type: text
        type: kafka
        brokers: broker_kafka_1
        topic: topic-kafka-1
    management-1:
        value_type: text
        type: kafka
        brokers: broker_kafka_2
        topic: topic-kafka-2
__END__

printf "*** SUMMARY OK=%d NG=%d\n" "$OK" "$NG"
test_dont_docker_down=true TEST_FINI
