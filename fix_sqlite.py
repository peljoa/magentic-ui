#!/usr/bin/env python3
"""
Fix for ChromaDB sqlite3 version issue.
This script replaces the built-in sqlite3 module with pysqlite3-binary.
"""

import sys

# Replace sqlite3 with pysqlite3 before any other imports
__import__('pysqlite3')
sys.modules['sqlite3'] = sys.modules.pop('pysqlite3')

# Now import chromadb to test
try:
    import chromadb
    print("✅ ChromaDB imported successfully with updated sqlite3!")
    
    # Test creating a client
    client = chromadb.Client()
    print("✅ ChromaDB client created successfully!")
    
except Exception as e:
    print(f"❌ Error: {e}")
    sys.exit(1)
