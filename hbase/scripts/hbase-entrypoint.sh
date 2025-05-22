#!/bin/bash

echo "$(date) Starting SSH service..."
sudo service ssh start

# Update hosts file
sudo /update-hosts.sh

# Echo environment variables
echo "JAVA_HOME=$JAVA_HOME"
echo "HBASE_HOME=$HBASE_HOME"
echo "PATH=$PATH"

# Test Java access
java -version

# Start services based on hostname
if [[ "$HOSTNAME" == "hm1" ]]; then
    # Wait for HDFS to be available
    echo "$(date) Checking if HDFS is available..."
    for i in {1..30}; do
        if hdfs dfs -ls / > /dev/null 2>&1; then
            echo "$(date) HDFS is available"
            break
        fi
        if [ $i -eq 30 ]; then
            echo "$(date) HDFS is not available after 30 attempts, continuing anyway..."
            break
        fi
        echo "$(date) Waiting for HDFS to be available... Attempt $i/30"
        sleep 10
    done

    # Create HBase directory in HDFS with proper replication
    echo "$(date) Creating HBase directory in HDFS..."
    hdfs dfs -mkdir -p /hbase || echo "Warning: Could not create /hbase directory in HDFS"
    hdfs dfs -chmod 755 /hbase || echo "Warning: Could not chmod /hbase directory in HDFS"
    
    echo "$(date) Starting HBase Master on $HOSTNAME..."
    $HBASE_HOME/bin/hbase-daemon.sh --config $HBASE_HOME/conf start master
    sleep 2
    jps || echo "jps command failed"
    
elif [[ "$HOSTNAME" == "hm2" ]]; then
    echo "$(date) Starting HBase Backup Master on $HOSTNAME..."
    $HBASE_HOME/bin/hbase-daemon.sh --config $HBASE_HOME/conf start master
    sleep 2
    jps || echo "jps command failed"
    
elif [[ "$HOSTNAME" =~ rs[0-9]+ ]]; then
    # Make sure required directories exist with correct permissions
    HADOOP_DATA_DIR="/data/hadoop/datanode"
    if [ ! -d "$HADOOP_DATA_DIR" ]; then
        echo "$(date) Creating DataNode data directory: $HADOOP_DATA_DIR"
        sudo mkdir -p $HADOOP_DATA_DIR
        sudo chown -R huser:hadoop $HADOOP_DATA_DIR
        sudo chmod -R 755 $HADOOP_DATA_DIR
    fi
    
    # Create YARN local dirs
    YARN_LOCAL_DIR="/data/hadoop/yarn/local"
    YARN_LOG_DIR="/data/hadoop/yarn/logs"
    if [ ! -d "$YARN_LOCAL_DIR" ] || [ ! -d "$YARN_LOG_DIR" ]; then
        echo "$(date) Creating YARN directories..."
        sudo mkdir -p $YARN_LOCAL_DIR $YARN_LOG_DIR
        sudo chown -R huser:hadoop $YARN_LOCAL_DIR $YARN_LOG_DIR
        sudo chmod -R 755 $YARN_LOCAL_DIR $YARN_LOG_DIR
    fi
    
    # This fixes the socket path issue seen in the logs
    if [ ! -d "/var/run/hadoop-hdfs" ]; then
        sudo mkdir -p /var/run/hadoop-hdfs
        sudo chmod 755 /var/run/hadoop-hdfs
        sudo chown huser:hadoop /var/run/hadoop-hdfs
    fi
    
    # Start DataNode with explicit data directory
    echo "$(date) Starting DataNode on worker node $(hostname)..."
    hdfs --daemon start datanode
    sleep 2
    
    
    # Start NodeManager
    echo "$(date) Starting NodeManager on worker node $(hostname)..."
    yarn --daemon start nodemanager
    sleep 2
    
    # Check if NodeManager started
    NM_PROC=$(jps | grep -c NodeManager)
    if [ "$NM_PROC" -eq 0 ]; then
        echo "$(date) WARNING: NodeManager did not start properly. Trying alternative method..."
        nohup yarn-daemon.sh start nodemanager > /tmp/nodemanager-start.log 2>&1 &
    else
        echo "$(date) NodeManager started successfully."
    fi
    
    # Start RegionServer
    echo "$(date) Starting HBase RegionServer on $HOSTNAME..."
    $HBASE_HOME/bin/hbase-daemon.sh --config $HBASE_HOME/conf start regionserver
    sleep 2
    
    # Display running Java processes
    echo "$(date) Running Java processes:"
    jps || echo "jps command failed"
    
else
    echo "$(date) Unknown role for $HOSTNAME"
fi

# Monitor the processes every 30 seconds
echo "$(date) Services started. Container is now running with monitoring..."
while true; do
    sleep 30
    echo "$(date) --- Service Status Check ---"
    RUNNING_PROCS=$(jps 2>/dev/null || echo "jps failed")
    echo "$RUNNING_PROCS"
    
    # For region servers, check and restart services if needed
    if [[ "$HOSTNAME" =~ rs[0-9]+ ]]; then
        # Check DataNode
        if ! echo "$RUNNING_PROCS" | grep -q "DataNode"; then
            echo "$(date) WARNING: DataNode not running, attempting restart..."
            # Try with a simpler config that disables short-circuit reads
            export HADOOP_OPTS="$HADOOP_OPTS -Ddfs.client.read.shortcircuit=false"
            hdfs --daemon start datanode
        fi
        
        # Check NodeManager
        if ! echo "$RUNNING_PROCS" | grep -q "NodeManager"; then
            echo "$(date) WARNING: NodeManager not running, attempting restart..."
            yarn --daemon start nodemanager
        fi
        
        # Check RegionServer
        if ! echo "$RUNNING_PROCS" | grep -q "HRegionServer"; then
            echo "$(date) WARNING: RegionServer not running, attempting restart..."
            $HBASE_HOME/bin/hbase-daemon.sh --config $HBASE_HOME/conf start regionserver
        fi
    fi
    
    # For master nodes, check and restart HMaster if needed
    if [[ "$HOSTNAME" == "hm1" || "$HOSTNAME" == "hm2" ]]; then
        if ! echo "$RUNNING_PROCS" | grep -q "HMaster"; then
            echo "$(date) WARNING: HBase Master not running, attempting restart..."
            $HBASE_HOME/bin/hbase-daemon.sh --config $HBASE_HOME/conf start master
        fi
    fi
done