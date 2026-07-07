#!/usr/bin/env python3
"""Wrap all API handlers with toVercel() and add it to imports."""
import re
import os
from pathlib import Path

API_DIR = Path('/home/z/my-project/download/sonic_cloud_flutter/api')

# Find all .js handler files (not in _lib/)
handler_files = []
for root, dirs, files in os.walk(API_DIR):
    if '_lib' in root:
        continue
    for f in files:
        if f.endswith('.js'):
            handler_files.append(Path(root) / f)

print(f"Found {len(handler_files)} handler files")

for fp in handler_files:
    rel = fp.relative_to(API_DIR)
    content = fp.read_text()
    orig = content
    
    # Determine the require depth for _lib/http
    depth = len(rel.parts) - 1  # number of parent dirs
    http_path = '../' * depth + '_lib/http'
    
    # 1. Add toVercel to the require from _lib/http
    # Match: const { ... } = require('../_lib/http');  or  require('./_lib/http')
    require_pattern = re.compile(
        r"const\s*\{([^}]+)\}\s*=\s*require\(['\"]" + re.escape(http_path) + r"['\"]\);"
    )
    m = require_pattern.search(content)
    if m:
        imports = m.group(1)
        if 'toVercel' not in imports:
            new_imports = imports.rstrip() + ', toVercel'
            content = content[:m.start()] + f"const {{{new_imports}}} = require('{http_path}');" + content[m.end():]
            print(f"  {rel}: added toVercel to imports")
    else:
        print(f"  {rel}: WARNING no require pattern matched for {http_path}")
    
    # 2. Wrap the handler with toVercel()
    # Pattern A: module.exports = handle(async (event) => {
    content, n_a = re.subn(
        r"module\.exports\s*=\s*handle\(\s*async\s*\(event\)\s*=>\s*\{",
        "module.exports = toVercel(async (event) => {",
        content,
    )
    # Pattern B: module.exports = async (event) => {  (status.js — no handle() wrapper)
    if n_a == 0:
        content, n_b = re.subn(
            r"module\.exports\s*=\s*async\s*\(event\)\s*=>\s*\{",
            "module.exports = toVercel(async (event) => {",
            content,
        )
        if n_b > 0:
            print(f"  {rel}: wrapped bare async handler with toVercel()")
    else:
        print(f"  {rel}: replaced handle() with toVercel() ({n_a} match)")
    
    if content != orig:
        fp.write_text(content)
    else:
        print(f"  {rel}: NO CHANGES")

print("\nDone.")
