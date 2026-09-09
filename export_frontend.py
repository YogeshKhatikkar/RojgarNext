# scripts/export_frontend.py
"""
Frontend Code Exporter for RojgarNext
Exports all Flutter frontend code to a single text file
Run: python scripts/export_frontend.py
"""

import os
import sys
from datetime import datetime
from pathlib import Path
from typing import List, Tuple

# ==================== CONFIGURATION ====================
# Frontend path - Update this to your actual frontend location
FRONTEND_PATH = r"H:\yogesh\website\rojgarnext\frontend"

# Output file
OUTPUT_FILE = "frontend_export.txt"

# Extensions to include
EXTENSIONS = ['.dart', '.yaml', '.yml', '.json', '.md', '.html', '.css', '.js']

# Folders to exclude
EXCLUDE_FOLDERS = [
    '.dart_tool', '.github', '.idea', '.vscode', 'build', 'node_modules',
    '.git', '__pycache__', 'venv', '.venv', 'env', '.env',
    'android', 'ios', 'linux', 'macos', 'windows', 'web', 'test'
]

# Files to exclude
EXCLUDE_FILES = [
    'pubspec.lock', '.flutter-plugins', '.flutter-plugins-dependencies',
    'gradle.properties', 'local.properties', 'flutter_export_environment.sh',
    'Podfile.lock', '.gitignore', '.metadata'
]

# Specific files to always include (even if in excluded patterns)
FORCE_INCLUDE = [
    'pubspec.yaml', 'analysis_options.yaml', 'Dockerfile', 'README.md'
]


# ==================== UTILITY FUNCTIONS ====================

def should_include_file(file_path: Path) -> bool:
    """Check if file should be included in export"""
    file_name = file_path.name
    
    # Force include specific files
    if file_name in FORCE_INCLUDE:
        return True
    
    # Check extension
    if file_path.suffix not in EXTENSIONS:
        return False
    
    # Check exclude list
    if file_name in EXCLUDE_FILES:
        return False
    
    return True


def should_include_folder(folder_path: Path) -> bool:
    """Check if folder should be traversed"""
    folder_name = folder_path.name
    
    # Check exclude list
    if folder_name in EXCLUDE_FOLDERS:
        return False
    
    # Skip hidden folders (starting with .)
    if folder_name.startswith('.') and folder_name not in FORCE_INCLUDE:
        return False
    
    return True


def get_all_files(root_path: Path) -> List[Path]:
    """Get all files to export recursively"""
    all_files = []
    
    try:
        for item in root_path.iterdir():
            if item.is_dir():
                if should_include_folder(item):
                    all_files.extend(get_all_files(item))
            else:
                if should_include_file(item):
                    all_files.append(item)
    except PermissionError:
        pass
    
    return all_files


def read_file_content(file_path: Path) -> Tuple[str, str]:
    """Read file content with proper encoding"""
    try:
        # Try UTF-8 first
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        return content, 'utf-8'
    except UnicodeDecodeError:
        try:
            # Try with replacement for binary files
            with open(file_path, 'r', encoding='utf-8', errors='replace') as f:
                content = f.read()
            return content, 'utf-8 (with replacements)'
        except Exception as e:
            return f"Error reading file: {e}", 'error'


def get_file_type_icon(extension: str) -> str:
    """Get icon for file type"""
    icons = {
        '.dart': '🎯',
        '.yaml': '⚙️',
        '.yml': '⚙️',
        '.json': '📋',
        '.md': '📝',
        '.html': '🌐',
        '.css': '🎨',
        '.js': '💛',
        '.txt': '📄',
    }
    return icons.get(extension, '📄')


# ==================== MAIN EXPORT FUNCTION ====================

def export_frontend():
    """Main export function"""
    
    print("=" * 80)
    print("🚀 FRONTEND CODE EXPORTER - RojgarNext")
    print("=" * 80)
    print()
    
    # Check if frontend path exists
    frontend_path = Path(FRONTEND_PATH)
    if not frontend_path.exists():
        print(f"❌ ERROR: Frontend path not found!")
        print(f"   Path: {FRONTEND_PATH}")
        print()
        print("Please update FRONTEND_PATH in the script to your actual frontend location.")
        sys.exit(1)
    
    print(f"📁 Source: {frontend_path}")
    print(f"📄 Output: {OUTPUT_FILE}")
    print()
    
    # Get all files
    print("📂 Scanning files...")
    all_files = get_all_files(frontend_path)
    
    # Sort files by path
    all_files.sort(key=lambda x: str(x))
    
    # Count by extension
    ext_count = {}
    for f in all_files:
        ext = f.suffix
        ext_count[ext] = ext_count.get(ext, 0) + 1
    
    print(f"✅ Found {len(all_files)} files to export")
    print()
    print("📊 File type breakdown:")
    for ext, count in sorted(ext_count.items(), key=lambda x: x[1], reverse=True):
        icon = get_file_type_icon(ext)
        print(f"   {icon} {ext}: {count} files")
    print()
    
    # Create export content
    print("✍️ Writing export file...")
    
    with open(OUTPUT_FILE, 'w', encoding='utf-8') as out_file:
        # Write header
        out_file.write("=" * 80 + "\n")
        out_file.write("ROJGARNEXT FRONTEND - COMPLETE CODE EXPORT\n")
        out_file.write("=" * 80 + "\n")
        out_file.write(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
        out_file.write(f"Source: {FRONTEND_PATH}\n")
        out_file.write(f"Total Files: {len(all_files)}\n")
        out_file.write("=" * 80 + "\n\n")
        
        # Write directory structure
        out_file.write("=" * 80 + "\n")
        out_file.write("📁 COMPLETE DIRECTORY STRUCTURE\n")
        out_file.write("=" * 80 + "\n\n")
        
        # Generate tree structure
        def write_tree(dir_path: Path, prefix: str = ""):
            items = sorted([item for item in dir_path.iterdir() if not item.name.startswith('.') or item.name in FORCE_INCLUDE])
            for i, item in enumerate(items):
                is_last = i == len(items) - 1
                current_prefix = "└── " if is_last else "├── "
                
                if item.is_dir():
                    # Check if directory should be shown (not excluded)
                    if item.name not in EXCLUDE_FOLDERS:
                        out_file.write(f"{prefix}{current_prefix}📁 {item.name}/\n")
                        next_prefix = prefix + ("    " if is_last else "│   ")
                        write_tree(item, next_prefix)
                else:
                    # Only show included files
                    if should_include_file(item):
                        icon = get_file_type_icon(item.suffix)
                        out_file.write(f"{prefix}{current_prefix}{icon} {item.name}\n")
        
        out_file.write("📁 frontend/rojgarnext/\n")
        write_tree(frontend_path, "")
        out_file.write("\n")
        
        # Write all file contents
        out_file.write("=" * 80 + "\n")
        out_file.write("📄 ALL FILE CONTENTS\n")
        out_file.write("=" * 80 + "\n\n")
        
        for i, file_path in enumerate(all_files, 1):
            rel_path = file_path.relative_to(frontend_path)
            extension = file_path.suffix
            icon = get_file_type_icon(extension)
            
            # Read file content
            content, encoding = read_file_content(file_path)
            
            # Write file header
            out_file.write("=" * 80 + "\n")
            out_file.write(f"[{i:3d}/{len(all_files):3d}] {icon} {rel_path}\n")
            out_file.write(f"📏 SIZE: {file_path.stat().st_size:,} bytes\n")
            out_file.write(f"🕐 MODIFIED: {datetime.fromtimestamp(file_path.stat().st_mtime).strftime('%Y-%m-%d %H:%M:%S')}\n")
            if encoding != 'utf-8':
                out_file.write(f"📝 ENCODING: {encoding}\n")
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
    print("   ✅ lib/ (all Dart files)")
    print("   ✅ pubspec.yaml")
    print("   ✅ analysis_options.yaml")
    print("   ✅ README.md")
    print("   ✅ Dockerfile")
    print()
    print("⚠️ WARNING: This file contains ALL your frontend code!")
    print("   Do not share it publicly.")
    print("=" * 80)


# ==================== ENTRY POINT ====================

if __name__ == "__main__":
    try:
        export_frontend()
    except KeyboardInterrupt:
        print("\n\n❌ Export cancelled by user.")
        sys.exit(1)
    except Exception as e:
        print(f"\n\n❌ Error during export: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
