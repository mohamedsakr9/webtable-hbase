FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive \
JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64 \
HADOOP_HOME=/Data/hadoop-3.3.6 \
HADOOP_MAPRED_HOME=/Data/hadoop-3.3.6 \
HADOOP_COMMON_HOME=/Data/hadoop-3.3.6 \
HADOOP_HDFS_HOME=/Data/hadoop-3.3.6 \
YARN_HOME=/Data/hadoop-3.3.6 \
HADOOP_CONF_DIR=/Data/hadoop-3.3.6/etc/hadoop \
YARN_CONF_DIR=/Data/hadoop-3.3.6/etc/hadoop \
ZOOKEEPER_HOME=/zookeeper-3.5.9 \
ZOOPIDFILE=/Data/zookeeper/zookeeper_server.pid \
ZOO_LOG_DIR=/zookeeper-3.5.9/logs \
NAMENODE_DIR=/Data/hadoop-3.3.6/namenode \
DATANODE_DIR=/Data/hadoop-3.3.6/datanode \
ZK_DIR=/Data/zookeeper \
PATH=${PATH}:/usr/lib/jvm/java-8-openjdk-amd64/bin:/Data/hadoop-3.3.6/bin:/Data/hadoop-3.3.6/sbin:/zookeeper-3.5.9/bin
RUN apt-get update && apt-get install -y \
    curl \
    gosu \
    openjdk-8-jdk \
    openssh-client \
    openssh-server \
    sudo \
    vim \
    wget \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /run/sshd \
    && addgroup hadoop && \
    adduser --disabled-password --gecos "" --ingroup hadoop huser && \
    echo "huser ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers && \
    chmod 750 /home/huser && \
    mkdir -p /Data \
             /Data/hadoop-3.3.6/logs \
             /Data/hadoop-3.3.6/data/jn \
             /Data/hadoop-3.3.6/namenode \
             /Data/hadoop-3.3.6/datanode \
             /Data/zookeeper \
             /Data/zookeeper/logs \
             /zookeeper-3.5.9/logs \
    && chown -R huser:hadoop /Data

ADD --chown=huser:hadoop ./Data/hadoop-3.3.6 /Data/hadoop-3.3.6

RUN wget -q https://archive.apache.org/dist/zookeeper/zookeeper-3.5.9/apache-zookeeper-3.5.9-bin.tar.gz && \
    mkdir -p /zookeeper-3.5.9 && \
    tar -xzf apache-zookeeper-3.5.9-bin.tar.gz -C / && \
    mv /apache-zookeeper-3.5.9-bin/* /zookeeper-3.5.9/ && \
    rm -rf /apache-zookeeper-3.5.9-bin apache-zookeeper-3.5.9-bin.tar.gz && \
    chown -R huser:hadoop /zookeeper-3.5.9 && \
    chmod 755 /zookeeper-3.5.9/logs

COPY --chown=huser:hadoop \
        configs/core-site.xml \
        configs/hdfs-site.xml \
        configs/yarn-site.xml \
        configs/mapred-site.xml \
        configs/hadoop-env.sh \
        configs/yarn-env.sh \
        /Data/hadoop-3.3.6/etc/hadoop/
COPY --chown=huser:hadoop configs/zoo.cfg /zookeeper-3.5.9/conf/
COPY --chown=huser:hadoop ./entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

USER huser
WORKDIR /home/huser
RUN mkdir -p ~/.ssh && \
    ssh-keygen -t rsa -P '' -f ~/.ssh/id_rsa && \
    cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys && \
    chmod 700 ~/.ssh && \
    chmod 600 ~/.ssh/*

ENTRYPOINT ["/entrypoint.sh"]