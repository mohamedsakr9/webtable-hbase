from faker import Faker
import random
import re
import hashlib
from datetime import datetime, timedelta
from typing import List, Dict

class WebTableWithIndexes:
    def __init__(self):
        self.fake = Faker()
        self.domains = ['example.com', 'test.org', 'demo.net', 'sample.co', 'web.io']
        
    def create_main_row_key(self, domain: str, url_path: str) -> str:
        """Create main table row key"""
        reversed_domain = '.'.join(reversed(domain.split('.')))
        path = url_path.lstrip('/') or 'home'
        clean_path = re.sub(r'[^a-zA-Z0-9\-_]', '_', path)[:25]
        return f"{reversed_domain}_{clean_path}"
    
    def create_index_keys(self, page_data: Dict) -> Dict:
        """Create all index keys for a page"""
        original_key = page_data['row_key']
        
        # Time index key
        timestamp = page_data['last_modified']
        date_str = datetime.fromtimestamp(timestamp).strftime('%Y%m%d')
        time_key = f"{date_str}_{original_key}"
        
        # Size index key
        size = page_data['content_size']
        if size < 1000:
            size_bucket = "small_0001KB"
        elif size < 10000:
            size_bucket = "medium_010KB"
        elif size < 100000:
            size_bucket = "large_0100KB"
        else:
            size_bucket = "huge_1000KB"
        size_key = f"{size_bucket}_{original_key}"
        
        # Link index keys
        inlinks = page_data['inlinks']
        outlinks = page_data['outlinks']
        
        def get_link_bucket(count):
            if count == 0: return "00"
            elif count <= 2: return "02" 
            elif count <= 5: return "05"
            elif count <= 10: return "10"
            else: return "99"
        
        inlink_key = f"inlinks_{get_link_bucket(inlinks)}_{original_key}"
        outlink_key = f"outlinks_{get_link_bucket(outlinks)}_{original_key}"
        
        # URL index key
        url_hash = hashlib.md5(page_data['url'].encode()).hexdigest()[:16]
        
        return {
            'time_index_key': time_key,
            'size_index_key': size_key,
            'inlink_index_key': inlink_key,
            'outlink_index_key': outlink_key,
            'url_index_key': url_hash
        }
    
    def generate_realistic_pages(self, count: int = 25) -> List[Dict]:
        """Generate realistic page dataset with all index data"""
        pages = []
        
        # Generate pages across domains
        for i in range(count):
            domain = random.choice(self.domains)
            
            # Generate different page types
            page_types = [
                ('home', '/'),
                ('about', '/about'),
                ('contact', '/contact'),
                ('blog', f'/blog/post-{i}'),
                ('products', f'/products/item-{i}'),
                ('services', '/services'),
                ('news', f'/news/article-{i}')
            ]
            
            page_type, path = random.choice(page_types)
            url = f"http://{domain}{path}"
            row_key = self.create_main_row_key(domain, path)
            
            # Realistic content generation
            if page_type == 'blog':
                content_size = random.randint(5000, 50000)  # Blog posts are longer
                title = f"Blog Post: {self.fake.sentence()}"
            elif page_type == 'products':
                content_size = random.randint(2000, 15000)  # Product pages medium
                title = f"Product: {self.fake.word().title()}"
            else:
                content_size = random.randint(500, 5000)    # Other pages smaller
                title = f"{page_type.title()}: {self.fake.sentence()}"
            
            # Generate content
            content_html = f"<html><head><title>{title}</title></head><body>"
            content_html += f"<h1>{title}</h1>"
            paragraphs_needed = content_size // 500  # Roughly 500 chars per paragraph
            for _ in range(max(1, paragraphs_needed)):
                content_html += f"<p>{self.fake.paragraph()}</p>"
            content_html += "</body></html>"
            content_html = content_html[:content_size]  # Trim to exact size
            
            # Realistic timestamps (more recent pages more common)
            days_ago = random.choices(
                range(0, 90),
                weights=[2.0 - min(1.8, day/50) for day in range(90)]
            )[0]
            last_modified = int((datetime.now() - timedelta(days=days_ago)).timestamp())
            
            # Realistic link patterns
            if page_type == 'home':
                outlinks = random.randint(5, 15)    # Home pages link to many pages
                inlinks = random.randint(1, 8)      # Home pages get some inlinks
            elif page_type == 'blog':
                outlinks = random.randint(2, 8)     # Blog posts have moderate outlinks
                inlinks = random.choices([0, 1, 2, 5, 12], weights=[20, 40, 25, 10, 5])[0]  # Some popular
            else:
                outlinks = random.randint(0, 5)     # Other pages have few outlinks
                inlinks = random.randint(0, 3)      # Most pages have few inlinks
            
            page_data = {
                'row_key': row_key,
                'domain': domain,
                'url': url,
                'path': path,
                'page_type': page_type,
                'title': title,
                'content_html': content_html,
                'content_size': len(content_html),
                'status_code': random.choices([200, 404, 500], weights=[92, 6, 2])[0],
                'last_modified': last_modified,
                'outlinks': outlinks,
                'inlinks': inlinks,
                'content_type': 'text/html'
            }
            
            # Generate index keys
            index_keys = self.create_index_keys(page_data)
            page_data.update(index_keys)
            
            pages.append(page_data)
        
        # Generate actual link URLs for some pages
        all_urls = [p['url'] for p in pages]
        for page in pages:
            if page['outlinks'] > 0:
                available_urls = [url for url in all_urls if url != page['url']]
                outbound_urls = random.sample(available_urls, min(page['outlinks'], len(available_urls)))
                page['outbound_urls'] = ';'.join(outbound_urls)
            else:
                page['outbound_urls'] = ''
            
            if page['inlinks'] > 0:
                available_urls = [url for url in all_urls if url != page['url']]
                inbound_urls = random.sample(available_urls, min(page['inlinks'], len(available_urls)))
                page['inbound_urls'] = ';'.join(inbound_urls)
            else:
                page['inbound_urls'] = ''
        
        return pages
    
    def generate_hbase_commands(self, pages: List[Dict]) -> Dict[str, List[str]]:
        """Generate HBase commands for main table and all indexes"""
        commands = {
            'main_table': [],
            'time_index': [],
            'size_index': [],
            'link_index': [],
            'url_index': []
        }
        
        for page in pages:
            row_key = page['row_key']
            
            # Main table commands
            main_cmds = [
                f"put 'webtable', '{row_key}', 'content:html', '{page['content_html'].replace(chr(39), chr(34))}'",
                f"put 'webtable', '{row_key}', 'content:size', '{page['content_size']}'",
                f"put 'webtable', '{row_key}', 'content:encoding', 'utf-8'",
                f"put 'webtable', '{row_key}', 'metadata:title', '{page['title'].replace(chr(39), chr(34))}'",
                f"put 'webtable', '{row_key}', 'metadata:domain', '{page['domain']}'",
                f"put 'webtable', '{row_key}', 'metadata:url', '{page['url']}'",
                f"put 'webtable', '{row_key}', 'metadata:status_code', '{page['status_code']}'",
                f"put 'webtable', '{row_key}', 'metadata:last_modified', '{page['last_modified']}'",
                f"put 'webtable', '{row_key}', 'metadata:page_type', '{page['page_type']}'",
                f"put 'webtable', '{row_key}', 'metadata:content_type', '{page['content_type']}'"
            ]
            
            # Add link data if present
            if page['outbound_urls']:
                main_cmds.extend([
                    f"put 'webtable', '{row_key}', 'outlinks:count', '{page['outlinks']}'",
                    f"put 'webtable', '{row_key}', 'outlinks:urls', '{page['outbound_urls']}'"
                ])
            
            if page['inbound_urls']:
                main_cmds.extend([
                    f"put 'webtable', '{row_key}', 'inlinks:count', '{page['inlinks']}'",
                    f"put 'webtable', '{row_key}', 'inlinks:urls', '{page['inbound_urls']}'"
                ])
            
            commands['main_table'].extend(main_cmds)
            
            # Index commands
            commands['time_index'].append(
                f"put 'webtable_time_idx', '{page['time_index_key']}', 'ref:rowkey', '{row_key}'"
            )
            
            commands['size_index'].append(
                f"put 'webtable_size_idx', '{page['size_index_key']}', 'ref:rowkey', '{row_key}'"
            )
            
            commands['link_index'].extend([
                f"put 'webtable_link_idx', '{page['inlink_index_key']}', 'ref:rowkey', '{row_key}'",
                f"put 'webtable_link_idx', '{page['outlink_index_key']}', 'ref:rowkey', '{row_key}'"
            ])
            
            commands['url_index'].append(
                f"put 'webtable_url_idx', '{page['url_index_key']}', 'ref:rowkey', '{row_key}'"
            )
        
        return commands

# Generate complete dataset
def generate_complete_dataset():
    generator = WebTableWithIndexes()
    pages = generator.generate_realistic_pages(25)
    commands = generator.generate_hbase_commands(pages)
    
    # Save all command files
    for table_type, cmd_list in commands.items():
        filename = f"load_{table_type}.hbase"
        with open(filename, 'w') as f:
            for cmd in cmd_list:
                f.write(cmd + '\n')
        print(f"Generated {filename} with {len(cmd_list)} commands")
    
    # Save page summary
    import json
    summary = {
        'total_pages': len(pages),
        'domains': list(set(p['domain'] for p in pages)),
        'page_types': list(set(p['page_type'] for p in pages)),
        'size_distribution': {
            'small': len([p for p in pages if p['content_size'] < 1000]),
            'medium': len([p for p in pages if 1000 <= p['content_size'] < 10000]),
            'large': len([p for p in pages if 10000 <= p['content_size'] < 100000]),
            'huge': len([p for p in pages if p['content_size'] >= 100000])
        },
        'sample_pages': [
            {
                'row_key': p['row_key'],
                'url': p['url'],
                'title': p['title'],
                'size': p['content_size'],
                'links_in': p['inlinks'],
                'links_out': p['outlinks']
            } for p in pages[:5]
        ]
    }
    
    with open('dataset_summary.json', 'w') as f:
        json.dump(summary, f, indent=2)
    
    print(f"\nDataset Summary:")
    print(f"- {len(pages)} pages generated")
    print(f"- {len(set(p['domain'] for p in pages))} domains")
    print(f"- Size distribution: {summary['size_distribution']}")

if __name__ == "__main__":
    generate_complete_dataset()

