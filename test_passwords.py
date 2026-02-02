#!/usr/bin/env python3

import argon2
import base64

def test_password(password, target_hash):
    """Test if a password matches the target hash"""
    try:
        # Use argon2 to verify the password directly
        ph = argon2.PasswordHasher()
        is_valid = ph.verify(target_hash, password)
        
        if is_valid:
            print(f"✅ PASSWORD FOUND: '{password}'")
            return True
        else:
            print(f"❌ '{password}' - Hash mismatch")
            return False
    except Exception as e:
        print(f"❌ '{password}' - Error: {e}")
        return False

# The target hash from the database
target_hash = "$argon2id$v=19$m=19456,t=2,p=1$c29tZXNhbHQ$RdescudvJC1OeqEcglpmXw"

# Common passwords to try
passwords_to_test = [
    "password",
    "password123", 
    "Password123!",
    "changeme",
    "ChangeMe123",
    "ChangeMe123!",
    "demo",
    "Demo123!",
    "alice",
    "Alice123!",
    "picshare",
    "PicShare123!",
    "welcome",
    "Welcome123!",
    "test",
    "Test123!",
]

print(f"Testing passwords against hash: {target_hash}")
print("=" * 60)

for password in passwords_to_test:
    if test_password(password, target_hash):
        break