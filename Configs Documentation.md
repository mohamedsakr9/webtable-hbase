# HBase Distributed Cluster Configuration Guide

## Overview

This guide documents a distributed HBase cluster configuration designed for containerized deployment with Docker. The setup includes HBase Masters (primary and backup), RegionServers, and integration with Hadoop HDFS.

## Architecture

### Cluster Topology
```
┌─────────────────────────────────────────────────────────────┐
│                    HBase Cluster                            │
├─────────────────────────────────────────────────────────────┤
│ Masters:                                                    │
│ ├── hm1 (Primary Master)                                    │
│ └── hm2 (Backup Master)                                     │
│                                                             │
│ RegionServers:                                              │
│ ├── rs1 (RegionServer + DataNode + NodeManager)             │
│ ├── rs2 (RegionServer + DataNode + NodeManager)             │
│ └── rs3 (RegionServer + DataNode + NodeManager)             │
│                                                             │
│ ZooKeeper Quorum:                                           │
│ ├── m1 (NameNode + ZooKeeper)                               │
│ ├── m2 (NameNode + ZooKeeper)                               │
│ └── m3 (NameNode + ZooKeeper)                               │
└─────────────────────────────────────────────────────────────┘
```

## Configuration Files

### 1. Dockerfile Configuration

**Base Image:** `opt-ha` (contains base Hadoop setup)
**HBase Version:** 2.4.18
**Java Version:** OpenJDK 8

#### Key Features:
- **User Management:** Runs as `huser` for security
- **Directory Structure:**
  - `/opt/hbase` - HBase installation
  - `/data/hbase` - HBase data and ZooKeeper data
  - `/opt/hbase/logs` - HBase logs
- **Network Tools:** netcat, ping, DNS utilities for cluster communication
- **Script Automation:** Automatic host resolution and service startup

### 2. HBase Site Configuration (`hbase-site.xml`)

#### Core Properties

| Property | Value | Purpose |
|----------|-------|---------|
| `hbase.cluster.distributed` | `true` | Enable distributed mode |
| `hbase.rootdir` | `hdfs://sakrcluster/hbase` | HBase data storage location |
| `hbase.zookeeper.quorum` | `m1,m2,m3` | ZooKeeper ensemble |
| `hbase.master.info.port` | `16010` | Web UI port |
| `hbase.wal.provider` | `filesystem` | Write-Ahead Log provider |

#### Cluster Management Properties

| Property | Value | Purpose |
|----------|-------|---------|
| `hbase.master.wait.on.regionservers.mintostart` | `1` | Minimum RegionServers to start |
| `hbase.assignments.client.timeout` | `300000` | Client timeout (5 minutes) |
| `hbase.master.loadbalancer.autoStartUp` | `false` | Manual load balancer control |
| `hbase.regionserver.hostname` | `$HOSTNAME` | Dynamic hostname resolution |

### 3. Cluster Membership

#### RegionServers (`regionservers`)
```
rs1
rs2
rs3
```

#### Backup Masters (`backup-masters`)
```
hm2
```

### 4. Environment Configuration (`hbase-env.sh`)

#### JVM Settings
```bash
export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
export HBASE_MANAGES_ZK=false  # External ZooKeeper
```


## Network Configuration

### Host Resolution (`update-hosts.sh`)

Automatically resolves and updates `/etc/hosts` for cluster nodes:

```bash
# Managed hosts
m1, m2, m3     # NameNodes + ZooKeeper
hm1, hm2       # HBase Masters  
rs1, rs2, rs3  # RegionServers
```

### Network Requirements

- **Internal Communication:** All nodes must be able to communicate on HBase ports
- **HDFS Integration:** RegionServers need access to HDFS NameNodes
- **ZooKeeper Access:** All HBase nodes need ZooKeeper connectivity
- **Web UI Access:** Port 16010 for HBase Master web interface

## Service Startup Sequence

### 1. Prerequisites Check
- SSH service startup
- Host resolution update
- Java environment validation
- HDFS availability check (for masters)

### 2. HBase Master Startup (hm1, hm2)
```bash
# Wait for HDFS
# Create HBase directory in HDFS
hdfs dfs -mkdir -p /hbase
hdfs dfs -chmod 755 /hbase

# Start HBase Master
$HBASE_HOME/bin/hbase-daemon.sh --config $HBASE_HOME/conf start master
```

### 3. RegionServer Startup (rs1, rs2, rs3)
```bash
# Create required directories
mkdir -p /data/hadoop/datanode
mkdir -p /data/hadoop/yarn/local
mkdir -p /data/hadoop/yarn/logs

# Start Hadoop services
hdfs --daemon start datanode
yarn --daemon start nodemanager

# Start HBase RegionServer
$HBASE_HOME/bin/hbase-daemon.sh --config $HBASE_HOME/conf start regionserver
```

## Monitoring and Health Checks

### Automated Process Monitoring
The entrypoint script includes continuous monitoring every 30 seconds:

#### Service Health Checks
- **DataNode:** Restart if not running
- **NodeManager:** Restart if not running  
- **RegionServer:** Restart if not running
- **HBase Master:** Restart if not running

### Health Check Commands



## Troubleshooting

### Common Issues

#### 1. RegionServer Connection Issues
**Symptoms:** RegionServers can't connect to Master
**Solutions:**
- Verify hostname resolution in `/etc/hosts`
- Check ZooKeeper connectivity
- Validate HDFS accessibility

#### 2. HDFS Directory Permissions
**Symptoms:** HBase can't write to HDFS
**Solutions:**
```bash
hdfs dfs -chown -R huser:hadoop /hbase
hdfs dfs -chmod -R 755 /hbase
```

#### 3. Memory Issues
**Symptoms:** OutOfMemoryError in logs
**Solutions:**
- Increase heap sizes in `hbase-env.sh`
- Monitor container memory limits
- Adjust GC settings

#### 4. Network Connectivity
**Symptoms:** Services can't communicate
**Solutions:**
- Verify Docker network configuration
- Check firewall rules
- Validate DNS resolution

### Log Locations
```
/opt/hbase/logs/                    # HBase logs
/data/hadoop/logs/                  # Hadoop logs  
/tmp/nodemanager-start.log          # NodeManager startup
```

## Performance Tuning






```

### RegionServer Tuning
```xml
<!-- Add to hbase-site.xml for production -->
<property>
  <name>hbase.regionserver.handler.count</name>
  <value>100</value>
</property>

<property>
  <name>hbase.hregion.memstore.flush.size</name>
  <value>134217728</value> <!-- 128MB -->
</property>

<property>
  <name>hbase.regionserver.global.memstore.size</name>
  <value>0.4</value> <!-- 40% of heap -->
</property>
```


