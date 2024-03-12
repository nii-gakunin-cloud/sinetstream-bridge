#!/bin/sh

. ./subr.sh

set -eux

OK=0
NG=0

GET_IPADDR broker_kafka_1

#test_dont_docker_down=true
#skip_default=true

TEST_INIT

START_MANAGEMENT_READER() {
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
    if "${skip-${skip_default-false}}";then
        return 0
    fi
    local ITEM EXPECTED ACTION EXPECTED_MSG1 EXPECTED_MSG2
    ITEM="$1"; shift
    EXPECTED="$1"; shift
    ACTION="$1"; shift
    EXPECTED_MSG1="$1"; shift
    EXPECTED_MSG2="$1"; shift
    PING="$1"; shift

    cat >tmp/.sinetstream_config.yml

    test "$EXPECTED_MSG2" = "" || START_MANAGEMENT_READER "management-1"

    TEST_INIT_BRIDGE "mybridge" && RES="$?" || RES="$?"
    #grep 'Exception:' tmp/bridge.out || true

    local RES
    if [ "$RES" = "$EXPECTED" ]; then
        printf "*** RESULT: OK %s\n" "$ITEM"
        OK=$((OK + 1))
    else
        printf "*** RESULT: NG %s: RES=%s != EXPECTED=%s\n" "$ITEM" "$RES" "$EXPECTED"
        NG=$((NG + 1))
    fi
    cat -n tmp/bridge.out

    if [ -n "$ACTION" ]; then
        eval "$ACTION"
    fi

    if [ -n "$EXPECTED_MSG1" ]; then
        if grep "$EXPECTED_MSG1" tmp/bridge.out; then
            printf "*** RESULT: OK %s\n" "$ITEM"
            OK=$((OK + 1))
        else
            printf "*** RESULT: NG %s: EXPECTED_MSG1=%s\n" "$ITEM" "$EXPECTED_MSG1"
            NG=$((NG + 1))
        fi
    fi

    if [ -n "$EXPECTED_MSG2" ]; then
        if grep "$EXPECTED_MSG2" tmp/management.out; then
            printf "*** RESULT: OK %s\n" "$ITEM"
            OK=$((OK + 1))
        else
            printf "*** RESULT: NG %s: EXPECTED_MSG2=%s\n" "$ITEM" "$EXPECTED_MSG2"
            NG=$((NG + 1))
        fi
        cat -n tmp/management.out

        kill $PID_MANAGEMENT
        wait $PID_MANAGEMENT || true
    fi

    if [ -n "$PING" ]; then
        TEST_PING $PING
    fi

    TEST_FINI_BRIDGE
}

TEST1 "started" 0 \
      "" \
      "SINETStream-Bridge:mybridge: STARTED" \
      "SINETStream-Bridge:mybridge: STARTED" \
      "upstream-1 downstream-1" \
      <<__END__
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
            report: management-1
    upstream-1:
        value_type: text
        type: mqtt
        brokers: broker_mqtt_1
        topic: topic-mqtt-1
        consistency: AT_LEAST_ONCE
    downstream-1:
        value_type: text
        type: kafka
        brokers: broker_kafka_1
        topic: topic-kafka-1
        consistency: AT_LEAST_ONCE
    management-1:
        value_type: text
        type: kafka
        brokers: broker_kafka_2
        topic: topic-kafka-2
        consistency: AT_LEAST_ONCE
__END__

TEST1 "bad-config-file" 1 \
      "" \
      "SINETStream-Bridge:.*sinetstream_config.yml: ERROR IN THE CONFIG FILE" \
      "" \
      "" \
      <<__END__
# note: v1 config format is not accepted.
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
    consistency: AT_LEAST_ONCE
downstream-1:
    value_type: text
    type: kafka
    brokers: broker_kafka_1
    topic: topic-kafka-1
    consistency: AT_LEAST_ONCE
__END__


TEST1 "bad-broker" 1 \
      "" \
      "SINETStream-Bridge:upstream-1: CONNECTION ERROR" \
      "SINETStream-Bridge:upstream-1: CONNECTION ERROR" \
      "" \
      <<__END__
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
            report: management-1
    upstream-1:
        value_type: text
        type: mqtt
        brokers: broker_mqtt_999
        topic: topic-mqtt-1
        consistency: AT_LEAST_ONCE
    downstream-1:
        value_type: text
        type: kafka
        brokers: broker_kafka_1
        topic: topic-kafka-1
        consistency: AT_LEAST_ONCE
    management-1:
        value_type: text
        type: kafka
        brokers: broker_kafka_2
        topic: topic-kafka-2
        consistency: AT_LEAST_ONCE
__END__

DCKILL() {
    local SERVICE="$1"
    case "$SERVICE" in
    *kafka*)
        #DOCKERCOMPOSE exec --no-TTY "$SERVICE" /bin/sh -c "pkill --full '/bin/sh /init.sh'"
        DOCKERCOMPOSE stop "$SERVICE"
        ;;
    *mqtt*)
        #DOCKERCOMPOSE exec --no-TTY "$SERVICE" /bin/sh -c "kill 1"
        DOCKERCOMPOSE stop "$SERVICE"
        ;;
    esac
}

TEST1 "upstream-kafka-down" 1 \
      "DCKILL broker_kafka_1 ; sleep 10 ; TEST_REUP ; sleep 3" \
      "SINETStream-Bridge:upstream-1: CONNECTION ERROR" \
      "SINETStream-Bridge:upstream-1: CONNECTION ERROR" \
      "upstream-1 downstream-1" \
      <<__END__
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
                connect_max: 0
                #connect_min_delay: 1
                #connect_max_delay: 1
            report: management-1
    downstream-1:
        value_type: text
        type: mqtt
        brokers: broker_mqtt_1
        topic: topic-mqtt-1
        consistency: AT_LEAST_ONCE
        reconnect_delay_set:
          max_delay: 1
          min_delay: 1
        connect:
          automatic_reconnect: true
    upstream-1:
        value_type: text
        type: kafka
        brokers: broker_kafka_1
        topic: topic-kafka-1
        consistency: AT_LEAST_ONCE
    management-1:
        value_type: text
        type: kafka
        brokers: broker_kafka_2
        topic: topic-kafka-2
        consistency: AT_LEAST_ONCE
__END__
TEST_REUP

TEST1 "upstream-mqtt-down" 1 \
      "DCKILL broker_mqtt_1 ; sleep 10 ; TEST_REUP ; sleep 3" \
      "SINETStream-Bridge:upstream-1: CONNECTION ERROR" \
      "SINETStream-Bridge:upstream-1: CONNECTION ERROR" \
      "upstream-1 downstream-1" \
      <<__END__
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
                connect_max: 0
                #connect_min_delay: 1
                #connect_max_delay: 1
            report: management-1
    upstream-1:
        value_type: text
        type: mqtt
        brokers: broker_mqtt_1
        topic: topic-mqtt-1
        consistency: AT_LEAST_ONCE
        reconnect_delay_set:
          max_delay: 1
          min_delay: 1
        connect:
          automatic_reconnect: true
    downstream-1:
        value_type: text
        type: kafka
        brokers: broker_kafka_1
        topic: topic-kafka-1
        consistency: AT_LEAST_ONCE
    management-1:
        value_type: text
        type: kafka
        brokers: broker_kafka_2
        topic: topic-kafka-2
        consistency: AT_LEAST_ONCE
__END__
TEST_REUP

TEST1 "downstream-kafka-down" 1 \
      "DCKILL broker_kafka_1 ; sleep 10 ; TEST_REUP ; sleep 3" \
      "SINETStream-Bridge:downstream-1: CONNECTION ERROR" \
      "SINETStream-Bridge:downstream-1: CONNECTION ERROR" \
      "upstream-1 downstream-1" \
      <<__END__
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
                connect_max: 0
                #connect_min_delay: 1
                #connect_max_delay: 1
            report: management-1
    upstream-1:
        value_type: text
        type: mqtt
        brokers: broker_mqtt_1
        topic: topic-mqtt-1
        consistency: AT_LEAST_ONCE
        reconnect_delay_set:
          max_delay: 1
          min_delay: 1
        connect:
          automatic_reconnect: true
    downstream-1:
        value_type: text
        type: kafka
        brokers: broker_kafka_1
        topic: topic-kafka-1
        consistency: AT_LEAST_ONCE
    management-1:
        value_type: text
        type: kafka
        brokers: broker_kafka_2
        topic: topic-kafka-2
        consistency: AT_LEAST_ONCE
__END__
TEST_REUP

TEST1 "downstream-mqtt-down" 1 \
      "DCKILL broker_mqtt_1 ; sleep 10 ; TEST_REUP ; sleep 3" \
      "SINETStream-Bridge:downstream-1: CONNECTION ERROR" \
      "SINETStream-Bridge:downstream-1: CONNECTION ERROR" \
      "upstream-1 downstream-1" \
      <<__END__
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
                connect_max: 0
                #connect_min_delay: 1
                #connect_max_delay: 1
            report: management-1
    downstream-1:
        value_type: text
        type: mqtt
        brokers: broker_mqtt_1
        topic: topic-mqtt-1
        consistency: AT_LEAST_ONCE
        reconnect_delay_set:
          max_delay: 1
          min_delay: 1
        connect:
          automatic_reconnect: true
    upstream-1:
        value_type: text
        type: kafka
        brokers: broker_kafka_1
        topic: topic-kafka-1
        consistency: AT_LEAST_ONCE
    management-1:
        value_type: text
        type: kafka
        brokers: broker_kafka_2
        topic: topic-kafka-2
        consistency: AT_LEAST_ONCE
__END__
TEST_REUP

printf "*** SUMMARY OK=%d NG=%d\n" "$OK" "$NG"
test_dont_docker_down=true TEST_FINI
