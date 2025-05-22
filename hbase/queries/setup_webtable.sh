#!/bin/bash
# setup_webtable.sh

echo "Setting up  WebTable with Secondary Indexes..."
echo "======================================================"

# 1. Create all tables
echo "Creating tables..."

hbase shell << 'EOF'
# Main table
create 'webtable',
  {NAME => 'content', VERSIONS => 3, TTL => 7776000},
  {NAME => 'metadata', VERSIONS => 1},
  {NAME => 'outlinks', VERSIONS => 2, TTL => 15552000},
  {NAME => 'inlinks', VERSIONS => 2, TTL => 15552000}

# Secondary indexes
create 'webtable_time_idx', {NAME => 'ref', VERSIONS => 1}
create 'webtable_size_idx', {NAME => 'ref', VERSIONS => 1}
create 'webtable_link_idx', {NAME => 'ref', VERSIONS => 1}
create 'webtable_url_idx', {NAME => 'ref', VERSIONS => 1}

# Verify tables
list
EOF

# 2. Generate test data
echo "Generating realistic test data..."
python3 data_generator.py

# 3. Load data
echo "Loading data into tables..."
hbase shell load_main_table.hbase
hbase shell load_time_index.hbase
hbase shell load_size_index.hbase
hbase shell load_link_index.hbase
hbase shell load_url_index.hbase

# 4. Verify setup
echo ""
echo "=== Setup Verification ==="

echo "Row counts:"
echo 'count "webtable"' | hbase shell -n
echo 'count "webtable_time_idx"' | hbase shell -n
echo 'count "webtable_size_idx"' | hbase shell -n
echo 'count "webtable_link_idx"' | hbase shell -n
echo 'count "webtable_url_idx"' | hbase shell -n

echo ""
echo "Sample queries:"
echo "Domain query (should be fast):"
time echo 'scan "webtable", {STARTROW => "com.example", ENDROW => "com.example~", LIMIT => 5}' | hbase shell -n > /dev/null

echo "Time index query:"
time echo 'scan "webtable_time_idx", {LIMIT => 5}' | hbase shell -n > /dev/null

echo ""
echo "Setup complete! WebTable with indexes ready for use."