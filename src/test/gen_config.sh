#!/bin/sh

set -eu

# example: ./gen_config.sh "upstream-1/mqtt/broker_mqtt_1/topic-mqtt-1" "downstream-1/kafka/broker_kafka_1/topic-kafka-1"

reader_spec_list="$1"; shift
writer_spec_list="$1"; shift
report_spec="${1:-}"

get_nth() {
    N="$1"; shift
    printf "%s" "$*" | cut -d/ -f"$N"
}
get_servicename() {
    get_nth 1 "$@"
}
get_type() {
    get_nth 2 "$@"
}
get_hostname() {
    get_nth 3 "$@"
}
get_topic() {
    get_nth 4 "$@"
}

indent() {
    sed 's/^/    /'
}

linefilter() {
    awk -v A="$1" -v B="$2" '
    {
        if (index($0, "#if " A) > 0) {
            if ((i = index($0, "#if " A " " B)) > 0) {
                # match
                print substr($0, 0, i - 1)
            } else {
                # unmatch
            }
        } else {
            # others
            print
        }
    }'
}

mapcar() {
    local fn="$1"; shift
    local X Y D
    Y=""
    D=""
    for X; do
        Y="$Y$D$(eval $fn "$X")"
        D=" "
    done
    printf "%s" "$Y"
}

print_list() {
    D=""
    for X; do
        printf "$D$X"
        D=", "
    done
}

cat <<__END__
header:
    version: 2
config:
    mybridge:
        type: bridge
        bridge:
            reader: [ $(print_list $(mapcar get_servicename $reader_spec_list)) ]
            writer: [ $(print_list $(mapcar get_servicename $writer_spec_list)) ]
            retry:
                connect_max: 9
                connect_min_delay: 1
                connect_max_delay: 8
            ${report_spec:+report: $(get_servicename $report_spec)}
            max_qlen: 10
__END__

for X in $reader_spec_list $writer_spec_list $report_spec; do
{ cat <<__END__
$(get_servicename $X):
    value_type: text
    type: $(get_type $X)
    brokers: $(get_hostname $X)
    topic: $(get_topic $X)
    consistency: AT_LEAST_ONCE
    reconnect_delay_set:        #if type mqtt
      max_delay: 4              #if type mqtt
      min_delay: 1              #if type mqtt
    connect:                    #if type mqtt
      automatic_reconnect: false #if type mqtt
__END__
} | linefilter type $(get_type $X)
done | indent
