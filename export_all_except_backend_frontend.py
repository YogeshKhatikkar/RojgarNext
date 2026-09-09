#!/usr/bin/env python3
"""
EXPORT ALL PROJECT FILES EXCLUDING BACKEND/FRONTEND FOLDERS
Exports: docker files, nginx config, scripts, monitoring, github workflows, etc.
Skips: backend/rojgarnext/, frontend/rojgarnext/, .venv/, and export files
"""

import os
import sys
from pathlib import Path
from datetime import datetime
from typing import List, Dict, Set
import fnmatch

# ==================== CONFIGURATION ====================
PROJECT_ROOT = Path(__file__).parent  # Current directory (project root)

OUTPUT_FILE = "rojgarnext_project_export.txt"

# ==================== EXCLUDE PATTERNS ====================
EXCLUDE_DIRS = {
    # Already have separate exporters for these
    'backend',           # Has its own export_backend_code.py
    'frontend',          # Has its own export_frontend.py
    
    # Virtual environments
    '.venv', 'venv', 'env', 'ENV', 'virtualenv',
    '__pycache__', '.pytest_cache', '.mypy_cache',
    
    # Version control
    '.git', '.svn', '.hg',
    
    # IDE
    '.idea', '.vscode', '.vs', '.atom',
    
    # Build outputs
    'build', 'dist', 'node_modules', '.dart_tool',
    'android', 'ios', 'linux', 'macos', 'windows', 'web',
    
    # Logs & temp
    'logs', 'tmp', 'temp', 'cache',
    
    # Backup
    'backups', 'backup',
}

EXCLUDE_FILES = {
    # Export files themselves
    'backend_complete_export.txt',
    'frontend_export.txt',
    'rojgarnext_project_export.txt',
    OUTPUT_FILE,
    
    # Hidden files
    '.DS_Store', 'Thumbs.db',
    
    # Lock files
    'pubspec.lock', 'package-lock.json', 'yarn.lock',
    
    # Python
    '*.pyc', '*.pyo', '*.pyd',
    
    # Logs
    '*.log', '*.pid',
    
    # Environment (sensitive)
    '.env', '.env.local', '.env.production',
}

EXCLUDE_EXTENSIONS = {
    '.pyc', '.pyo', '.pyd', '.so', '.dll', '.exe',
    '.jpg', '.jpeg', '.png', '.gif', '.ico', '.svg',
    '.mp4', '.mp3', '.wav', '.avi',
    '.zip', '.tar', '.gz', '.rar', '.7z',
    '.db', '.sqlite', '.sqlite3',
}

EXCLUDE_PATTERNS = [
    '*__pycache__*',
    '*.egg-info*',
    '*.pytest_cache*',
]

# ==================== INCLUDE PATTERNS (Override excludes) ====================
FORCE_INCLUDE_FILES = {
    'docker-compose.yml',
    'docker-compose.simple.yml',
    'docker-compose.single.yml',
    'nginx.conf',
    'start.sh',
    'stop.sh',
    'rebuild.sh',
    'run.bat',
    'deploy.sh',
    'package.json',
    'README.md',
    '.gitignore',
}

FORCE_INCLUDE_DIRS = {
    'monitoring',
    'scripts',
    '.github',
    'nginx',
    'secrets',
}

# ==================== UTILITY FUNCTIONS ====================

def should_exclude_path(path: Path, root: Path) -> bool:
    """Check if path should be excluded"""
    rel_path = path.relative_to(root)
    parts = rel_path.parts
    
    # Force include specific dirs at any level
    for force_dir in FORCE_INCLUDE_DIRS:
        if force_dir in parts:
            return False
    
    # Force include specific files
    if path.name in FORCE_INCLUDE_FILES:
        return False
    
    # Check exclude patterns
    for pattern in EXCLUDE_PATTERNS:
        if fnmatch.fnmatch(str(rel_path), pattern):
            return True
    
    # Check exclude directories
    if path.is_dir():
        if path.name in EXCLUDE_DIRS:
            return True
        # Skip hidden directories
        if path.name.startswith('.') and path.name not in FORCE_INCLUDE_FILES:
            return True
    
    # Check exclude files
    if path.is_file():
        if path.name in EXCLUDE_FILES:
            return True
        # Check extension
        if path.suffix in EXCLUDE_EXTENSIONS:
            return True
        # Skip hidden files
        if path.name.startswith('.') and path.name not in FORCE_INCLUDE_FILES:
            return True
    
    return False


def get_all_files(root: Path) -> List[Path]:
    """Get all files to export recursively"""
    all_files = []
    
    try:
        for item in root.iterdir():
            if should_exclude_path(item, root):
                continue
            
            if item.is_dir():
                all_files.extend(get_all_files(item))
            else:
                all_files.append(item)
    except PermissionError:
        pass
    
    return all_files


def get_file_type_icon(file_path: Path) -> str:
    """Get icon for file type"""
    name = file_path.name
    suffix = file_path.suffix.lower()
    
    # Docker files
    if name.startswith('docker-compose') or name == 'Dockerfile':
        return '🐳'
    
    # Config files
    if suffix in ['.yml', '.yaml']:
        return '⚙️'
    if suffix == '.conf':
        return '🔧'
    if name == 'nginx.conf':
        return '🌐'
    
    # Scripts
    if suffix == '.sh':
        return '📜'
    if suffix == '.bat':
        return '🪟'
    if suffix == '.ps1':
        return '💻'
    
    # Python
    if suffix == '.py':
        return '🐍'
    
    # Web
    if suffix == '.js':
        return '💛'
    if suffix == '.html':
        return '🌐'
    if suffix == '.css':
        return '🎨'
    
    # JSON
    if suffix == '.json':
        return '📋'
    
    # Markdown
    if suffix == '.md':
        return '📝'
    
    # Text
    if suffix == '.txt':
        return '📄'
    
    # Default
    return '📄'


def read_file_content(file_path: Path) -> str:
    """Read file content with proper encoding"""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            return f.read()
    except UnicodeDecodeError:
        try:
            with open(file_path, 'r', encoding='latin-1') as f:
                return f.read()
        except Exception as e:
            return f"[ERROR: Could not read file - {e}]"
    except Exception as e:
        return f"[ERROR: Could not read file - {e}]"


def generate_tree_structure(root: Path, prefix: str = "", is_root: bool = True) -> List[str]:
    """Generate directory tree structure"""
    lines = []
    
    if is_root:
        lines.append(f"📁 {root.name}/")
        current_prefix = ""
    else:
        current_prefix = prefix
    
    try:
        items = []
        for item in sorted(root.iterdir()):
            if should_exclude_path(item, root):
                continue
            items.append(item)
        
        for i, item in enumerate(items):
            is_last = (i == len(items) - 1)
            connector = "└── " if is_last else "├── "
            
            if item.is_dir():
                icon = "📁"
                lines.append(f"{current_prefix}{connector}{icon} {item.name}/")
                extension = "    " if is_last else "│   "
                lines.extend(generate_tree_structure(item, current_prefix + extension, False))
            else:
                icon = get_file_type_icon(item)
                lines.append(f"{current_prefix}{connector}{icon} {item.name}")
    except Exception as e:
        lines.append(f"{current_prefix}[Error: {e}]")
    
    return lines


# ==================== MAIN EXPORT FUNCTION ====================

def main():
    """Main export function"""
    print("=" * 80)
    print("📦 ROJGARNEXT PROJECT EXPORTER")
    print("=" * 80)
    print()
    
    if not PROJECT_ROOT.exists():
        print(f"❌ ERROR: Project root not found!")
        print(f"   Path: {PROJECT_ROOT}")
        sys.exit(1)
    
    print(f"📁 Source: {PROJECT_ROOT}")
    print(f"📄 Output: {OUTPUT_FILE}")
    print()
    print("⏭️  EXCLUDED:")
    print("   📁 backend/ (has its own exporter)")
    print("   📁 frontend/ (has its own exporter)")
    print("   📁 .venv/ (virtual environment)")
    print("   📄 backend_complete_export.txt")
    print("   📄 frontend_export.txt")
    print("   📄 rojgarnext_project_export.txt")
    print()
    
    # Get all files
    print("📂 Scanning files...")
    all_files = get_all_files(PROJECT_ROOT)
    all_files.sort(key=lambda x: str(x))
    
    # Count by type
    type_count = {}
    for f in all_files:
        icon = get_file_type_icon(f)
        type_count[icon] = type_count.get(icon, 0) + 1
    
    print(f"✅ Found {len(all_files)} files to export")
    print()
    print("📊 File type breakdown:")
    for icon, count in sorted(type_count.items(), key=lambda x: x[1], reverse=True):
        print(f"   {icon}: {count} files")
    print()
    
    # Create export content
    print("✍️ Writing export file...")
    
    with open(OUTPUT_FILE, 'w', encoding='utf-8') as out_file:
        # Write header
        out_file.write("=" * 80 + "\n")
        out_file.write("ROJGARNEXT PROJECT - COMPLETE EXPORT\n")
        out_file.write("=" * 80 + "\n")
        out_file.write(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
        out_file.write(f"Source: {PROJECT_ROOT}\n")
        out_file.write(f"Total Files: {len(all_files)}\n")
        out_file.write("=" * 80 + "\n\n")
        
        # Write excluded note
        out_file.write("=" * 80 + "\n")
        out_file.write("⚠️ EXCLUDED FOLDERS/FILES\n")
        out_file.write("=" * 80 + "\n")
        out_file.write("""
The following folders have been EXCLUDED from this export:
  📁 backend/rojgarnext/     - Has separate export (backend_complete_export.txt)
  📁 frontend/rojgarnext/    - Has separate export (frontend_export.txt)
  📁 .venv/                  - Virtual environment
  📄 *.txt export files      - Previous exports

For backend code, run:  python export_backend_code.py
For frontend code, run: python export_frontend.py

""")
        out_file.write("\n")
        
        # Write directory structure
        out_file.write("=" * 80 + "\n")
        out_file.write("📁 COMPLETE DIRECTORY STRUCTURE (Excluding backend/frontend)\n")
        out_file.write("=" * 80 + "\n\n")
        
        tree_lines = generate_tree_structure(PROJECT_ROOT)
        for line in tree_lines:
            out_file.write(line + "\n")
        out_file.write("\n\n")
        
        # Write all file contents
        out_file.write("=" * 80 + "\n")
        out_file.write("📄 ALL FILE CONTENTS\n")
        out_file.write("=" * 80 + "\n\n")
        
        for i, file_path in enumerate(all_files, 1):
            rel_path = file_path.relative_to(PROJECT_ROOT)
            icon = get_file_type_icon(file_path)
            size = file_path.stat().st_size
            
            # Read file content
            content = read_file_content(file_path)
            
            # Write file header
            out_file.write("=" * 80 + "\n")
            out_file.write(f"[{i:4d}/{len(all_files):4d}] {icon} {rel_path}\n")
            out_file.write(f"📏 SIZE: {size:,} bytes\n")
            out_file.write(f"🕐 MODIFIED: {datetime.fromtimestamp(file_path.stat().st_mtime).strftime('%Y-%m-%d %H:%M:%S')}\n")
            out_file.write("=" * 80 + "\n\n")
            
            # Write content
            out_file.write(content)
            out_file.write("\n\n")
        
        # Write footer
        out_file.write("=" * 80 + "\n")
        out_file.write("🎉 EXPORT COMPLETED!\n")
        out_file.write("=" * 80 + "\n")
        out_file.write(f"Total Files: {len(all_files)}\n")
        out_file.write(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
        out_file.write("=" * 80 + "\n")
    
    # Calculate file size
    output_size = os.path.getsize(OUTPUT_FILE)
    
    print()
    print("=" * 80)
    print("🎉 EXPORT COMPLETED SUCCESSFULLY!")
    print("=" * 80)
    print(f"📄 Output file: {OUTPUT_FILE}")
    print(f"📊 Total files exported: {len(all_files)}")
    print(f"💾 File size: {output_size:,} bytes ({output_size / (1024*1024):.2f} MB)")
    print()
    print("📁 Files exported include:")
    print("   ✅ docker-compose.yml files")
    print("   ✅ nginx.conf")
    print("   ✅ start.sh, stop.sh, rebuild.sh, run.bat")
    print("   ✅ deploy.sh, package.json")
    print("   ✅ .github/workflows/ (CI/CD)")
    print("   ✅ monitoring/ (prometheus, logstash)")
    print("   ✅ scripts/")
    print("   ✅ README.md, .gitignore")
    print()
    print("⚠️ NOTE: backend/ and frontend/ folders are EXCLUDED!")
    print("   For backend code: python export_backend_code.py")
    print("   For frontend code: python export_frontend.py")
    print("=" * 80)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n\n❌ Export cancelled by user.")
        sys.exit(1)
    except Exception as e:
        print(f"\n\n❌ Error during export: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
