#!/usr/bin/env bash
export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
export HBASE_MANAGES_ZK=false
export HBASE_HEAPSIZE=1G
export HBASE_LOG_DIR=/opt/hbase/logs
# Critical for proper network resolution
export HBASE_OPTS="$HBASE_OPTS -Djava.net.preferIPv4Stack=true -XX:+UseConcMarkSweepGC -XX:CMSInitiatingOccupancyFraction=70"
# Add explicit hostname settings
export HBASE_REGIONSERVER_OPTS="$HBASE_REGIONSERVER_OPTS -Xms1G -Xmx1G"
export HBASE_MASTER_OPTS="$HBASE_MASTER_OPTS -Xms1G -Xmx1G"