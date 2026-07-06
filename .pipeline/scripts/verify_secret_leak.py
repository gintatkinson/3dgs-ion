#!/usr/bin/env python3
import os
import re
import sys
import json
import math

def compute_entropy(s):
    if not s:
        return 0.0
    char_counts = {}
    for char in s:
        char_counts[char] = char_counts.get(char, 0) + 1
    total_len = len(s)
    entropy = 0.0
    for count in char_counts.values():
        p = count / total_len
        entropy -= p * math.log2(p)
    return entropy

# Banned signatures
PEM_PATTERN = re.compile(r'-----BEGIN\s+(?:[A-Z0-9_\-\s]+)?PRIVATE\s+KEY-----', re.IGNORECASE)
JWT_PATTERN = re.compile(r'\bey[a-zA-Z0-9_\-]+\.ey[a-zA-Z0-9_\-]+\.[a-zA-Z0-9_\-]+\b')
AWS_KEY_PATTERN = re.compile(r'\bAKIA[0-9A-Z]{16}\b')
DB_CONN_PATTERN = re.compile(r'\b(?:postgresql|mongodb|mysql|oracle|mssql)://[a-zA-Z0-9_\-]+:[^@\s]+@[a-zA-Z0-9_\.\-]+:\d+/[a-zA-Z0-9_\-]+', re.IGNORECASE)
GCP_SA_PATTERN = re.compile(r'"type":\s*"service_account"', re.IGNORECASE)

BANNED_JSON_KEYS = ["password", "secret", "private_key", "aws_secret_access_key"]

def scan_file(filepath, workspace_dir):
    rel_path = os.path.relpath(filepath, workspace_dir)
    errors = []
    
    # Try reading file contents
    try:
        with open(filepath, "r", encoding="utf-8", errors="ignore") as f:
            content = f.read()
    except Exception as e:
        return [f"Failed to read file {rel_path}: {e}"]

    # 1. Regex signature scans
    if PEM_PATTERN.search(content):
        errors.append(f"File {rel_path} contains a raw PEM Private Key block.")
    if AWS_KEY_PATTERN.search(content):
        errors.append(f"File {rel_path} contains a potential AWS Access Key ID.")
    if DB_CONN_PATTERN.search(content):
        errors.append(f"File {rel_path} contains a database connection string with credentials.")
    if GCP_SA_PATTERN.search(content):
        errors.append(f"File {rel_path} contains a GCP Service Account JSON structure.")
    if JWT_PATTERN.search(content):
        errors.append(f"File {rel_path} contains a potential JWT bearer token.")

    # 2. JSON key scans
    ext = os.path.splitext(filepath)[1].lower()
    if ext == ".json":
        try:
            data = json.loads(content)
            def check_keys(obj):
                local_errs = []
                if isinstance(obj, dict):
                    for k, v in obj.items():
                        if any(banned in k.lower() for banned in BANNED_JSON_KEYS):
                            # Allow empty values or env var templates
                            if isinstance(v, str) and v.strip() and not v.startswith("${") and not v.startswith("ENV_"):
                                local_errs.append(f"File {rel_path} contains a key '{k}' with a potential hardcoded secret/password.")
                        local_errs.extend(check_keys(v))
                elif isinstance(obj, list):
                    for item in obj:
                        local_errs.extend(check_keys(item))
                return local_errs
            errors.extend(check_keys(data))
        except:
            pass

    # 3. High-entropy string scanning (mainly for compiled js/css/tokens/json strings)
    # Extract long strings (potential keys) and check their entropy
    # Looking for base64 / hex/ alphanumeric strings of length >= 32
    # Standard regex to find base64/hex words of length 32-128
    word_pattern = re.compile(r'\b[a-zA-Z0-9+/=_\-]{32,128}\b')
    for match in word_pattern.finditer(content):
        word = match.group(0)
        # Avoid standard styling, SVG paths, base64 data URLs (e.g. data:image/png) or common long words
        if "data:image" in word or "px" in word or word.startswith("M") or word.startswith("m"):
            continue
        entropy = compute_entropy(word)
        # Banned high entropy (randomness) threshold > 4.8 for keys
        # We also check that the word consists of mixed case or mixed digits to reduce false positives
        has_digit = any(c.isdigit() for c in word)
        has_upper = any(c.isupper() for c in word)
        has_lower = any(c.islower() for c in word)
        # A good heuristic: it must have at least two of these classes
        if (has_digit + has_upper + has_lower) >= 2:
            if entropy > 4.8:
                errors.append(f"File {rel_path} contains a high-entropy string candidate (Entropy: {entropy:.2f}): '{word[:10]}...{word[-5:]}'")

    return errors

def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    workspace_dir = os.path.abspath(os.path.join(script_dir, "..", ".."))

    # Scan paths relative to workspace
    scan_dirs = ["dist", "build/web", "build/macos"]
    found_any = False
    all_errors = []

    print("=== Post-Build CI Secret Leak Scanner ===")
    
    for d in scan_dirs:
        target_path = os.path.join(workspace_dir, d)
        if os.path.exists(target_path):
            found_any = True
            print(f"Scanning directory: {d}")
            for root, _, files in os.walk(target_path):
                for file in files:
                    filepath = os.path.join(root, file)
                    file_errors = scan_file(filepath, workspace_dir)
                    all_errors.extend(file_errors)
        else:
            print(f"Directory not found (skipped): {d}")

    if not found_any:
        print("\nNote: None of the post-build directories exist. Skipping scan. (Run build first to generate assets for scanning)")
        sys.exit(0)

    if all_errors:
        print("\n[!] CI Security Gate Failure: Potential Secrets or Credentials Leaked:")
        for err in all_errors:
            print(f"  - {err}")
        sys.exit(1)
    else:
        print("\nSuccess: No secret leaks detected in post-build assets.")
        sys.exit(0)

if __name__ == "__main__":
    main()
