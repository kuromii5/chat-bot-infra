FROM debezium/connect:2.7.3.Final

USER root

RUN curl -L -o /tmp/kafka-connect-elasticsearch.zip \
    "https://api.hub.confluent.io/api/plugins/confluentinc/kafka-connect-elasticsearch/versions/15.0.0/archive" \
    && unzip /tmp/kafka-connect-elasticsearch.zip -d /kafka/connect/ \
    && rm /tmp/kafka-connect-elasticsearch.zip

USER 1001
