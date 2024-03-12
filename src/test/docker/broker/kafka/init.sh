#!/bin/sh

set -ex

# https://kafka.apache.org/quickstart
# STEP 2: START THE KAFKA ENVIRONMENT
# Kafka with KRaft
if ! [ -f /tmp/KAFKA_INITIALIZED.stamp ]; then
    sed --in-place '/^advertised.listeners=/s/^/#/' config/kraft/server.properties
    bin/kafka-storage.sh random-uuid >/tmp/KAFKA_CLUSTER_ID
    bin/kafka-storage.sh format -t "$(cat /tmp/KAFKA_CLUSTER_ID)" -c config/kraft/server.properties
    touch /tmp/KAFKA_INITIALIZED.stamp
fi
bin/kafka-server-start.sh config/kraft/server.properties &

## STEP 3: CREATE A TOPIC TO STORE YOUR EVENTS
#for TOPIC in ${TOPIC_LIST}; do
#    bin/kafka-topics.sh --create --topic ${TOPIC} --bootstrap-server localhost:9092
#done

# END
while :; do
sleep $((24 * 60 * 60))
done
