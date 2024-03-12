FROM openjdk:11-slim

ENV KAFKA_VER=3.5.0
ENV SCALA_VER=2.13
ENV KAFKA=kafka_${SCALA_VER}-${KAFKA_VER}

#ENV TOPIC_LIST="topic-kafka-1 topic-kafka-2 topic-kafka-3 topic-kafka-4"

# https://kafka.apache.org/quickstart
# STEP 1: GET KAFKA
# note: pkill is in procfs
RUN apt update
RUN apt install -y wget procps
WORKDIR /tmp
RUN wget https://dlcdn.apache.org/kafka/${KAFKA_VER}/${KAFKA}.tgz
RUN tar xf ${KAFKA}.tgz
WORKDIR ${KAFKA}

COPY init.sh /
CMD /init.sh
