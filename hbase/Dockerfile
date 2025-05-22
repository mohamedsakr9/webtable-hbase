FROM opt-ha

# HBase Version
ENV HBASE_VERSION=2.4.18 \
    HBASE_HOME=/opt/hbase \
    PATH=${PATH}:/opt/hbase/bin \
    JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64

USER root

# Install necessary packages
RUN apt-get update && \
    apt-get install -y netcat-openbsd iputils-ping dnsutils dos2unix && \
    apt-get clean

# Install HBase
RUN wget -q https://downloads.apache.org/hbase/${HBASE_VERSION}/hbase-${HBASE_VERSION}-bin.tar.gz && \
    mkdir -p /opt/hbase && \
    tar -xzf hbase-${HBASE_VERSION}-bin.tar.gz -C /opt && \
    mv /opt/hbase-${HBASE_VERSION}/* /opt/hbase/ && \
    rm -rf /opt/hbase-${HBASE_VERSION} hbase-${HBASE_VERSION}-bin.tar.gz && \
    mkdir -p /opt/hbase/logs /data/hbase/data /data/hbase/zk && \
    chmod -R 777 /opt/hbase/logs /data/hbase && \
    chown -R huser:hadoop /opt/hbase /data/hbase

# Copy configuration files
COPY ./hbase-site.xml /opt/hbase/conf/
COPY ./regionservers /opt/hbase/conf/
COPY ./backup-masters /opt/hbase/conf/

# Copy scripts
COPY ./scripts/update-hosts.sh /update-hosts.sh
COPY ./scripts/hbase-env.sh /opt/hbase/conf/hbase-env.sh
COPY ./scripts/hbase-entrypoint.sh /hbase-entrypoint.sh
RUN dos2unix /update-hosts.sh /opt/hbase/conf/hbase-env.sh /hbase-entrypoint.sh && \
    chmod +x /update-hosts.sh /opt/hbase/conf/hbase-env.sh /hbase-entrypoint.sh

USER huser
WORKDIR /home/huser
ENTRYPOINT ["/bin/bash", "/hbase-entrypoint.sh"]