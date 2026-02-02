#!/usr/bin/env python3

import argon2
import base64

# Create Argon2 hasher with the same parameters as the seed data
ph = argon2.PasswordHasher(
    time_cost=2,      # t=2
    memory_cost=19456, # m=19456 (in KB)
    parallelism=1,    # p=1
    hash_len=32,      # default hash length
    salt_len=16       # default salt length
)

password = "ChangeMe123!"
hash_result = ph.hash(password)

print("Generated hash for 'ChangeMe123!':")
print(hash_result)

# Also try with the fixed salt from the seed data
fixed_salt = b"somesalt"
try:
    hash_with_fixed_salt = ph.hash(password, salt=fixed_salt)
    print("\nGenerated hash with fixed salt 'somesalt':")
    print(hash_with_fixed_salt)
except Exception as e:
    print(f"\nError with fixed salt: {e}")