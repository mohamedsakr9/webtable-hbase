#!/bin/bash
# test_all_business_requirements.sh

echo "WebTable Business Requirements Test Suite"
echo "========================================"

echo ""
echo "=== Content Management Tests ==="

echo "1. Domain audit (example.com):"
hbase shell -n << 'EOF'
scan 'webtable', {
  STARTROW => 'com.example',
  ENDROW => 'com.example~',
  COLUMNS => ['metadata:url', 'metadata:title'],
  LIMIT => 5
}
EOF

echo ""
echo "2. Page version history:"
hbase shell -n << 'EOF'
get 'webtable', 'com.example_about', {
  COLUMN => 'content:html',
  VERSIONS => 3
}
EOF

echo ""
echo "3. Recent pages (via time index):"
TODAY=$(date +%Y%m%d)
WEEK_AGO=$(date -d '7 days ago' +%Y%m%d)
hbase shell -n << EOF
scan 'webtable_time_idx', {
  STARTROW => '${WEEK_AGO}',
  ENDROW => '${TODAY}~',
  COLUMNS => ['ref:rowkey'],
  LIMIT => 5
}
EOF

echo ""
echo "=== SEO Analysis Tests ==="

echo "4. Popular pages (high inbound links):"
hbase shell -n << 'EOF'
scan 'webtable_link_idx', {
  STARTROW => 'inlinks_02',
  ENDROW => 'inlinks_99~',
  COLUMNS => ['ref:rowkey'],
  LIMIT => 5
}
EOF

echo ""
echo "5. Dead end pages (no outbound links):"
hbase shell -n << 'EOF'
scan 'webtable_link_idx', {
  STARTROW => 'outlinks_00',
  ENDROW => 'outlinks_00~',
  COLUMNS => ['ref:rowkey'],
  LIMIT => 5
}
EOF

echo ""
echo "6. Content search:"
hbase shell -n << 'EOF'
scan 'webtable', {
  FILTER => "SingleColumnValueFilter('metadata', 'title', =, 'substring:Blog')",
  COLUMNS => ['metadata:url', 'metadata:title'],
  LIMIT => 5
}
EOF

echo ""
echo "=== Performance Optimization Tests ==="

echo "7. Large pages (via size index):"
hbase shell -n << 'EOF'
scan 'webtable_size_idx', {
  STARTROW => 'medium_010KB',
  ENDROW => 'huge_1000KB~',
  COLUMNS => ['ref:rowkey'],
  LIMIT => 5
}
EOF

echo ""
echo "8. Error pages:"
hbase shell -n << 'EOF'
scan 'webtable', {
  FILTER => "SingleColumnValueFilter('metadata', 'status_code', >=, 'binary:400')",
  COLUMNS => ['metadata:url', 'metadata:status_code'],
  LIMIT => 5
}
EOF

