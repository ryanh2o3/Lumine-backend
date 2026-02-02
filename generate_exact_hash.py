#!/usr/bin/env python3

import argon2
import base64

# Generate a hash with exact parameters matching the Rust code
password = "password123"
salt = b"somesalt"  # 8 bytes

# Create hasher with exact parameters
ph = argon2.PasswordHasher(
    time_cost=2,      # t=2
    memory_cost=19456, # m=19456 (in KB)
    parallelism=1,    # p=1
    hash_len=32,      # 32 bytes
    salt_len=8        # 8 bytes to match "somesalt"
)

# Generate hash with the fixed salt
hash_result = ph.hash(password, salt=salt)

print("Generated hash for 'password123' with salt 'somesalt':")
print(hash_result)

# Verify it works
try:
    is_valid = ph.verify(hash_result, password)
    print(f"\nVerification result: {is_valid}")
except Exception as e:
    print(f"\nVerification error: {e}")