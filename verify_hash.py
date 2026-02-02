#!/usr/bin/env python3

import argon2

# The hash I generated for "password123"
generated_hash = "$argon2id$v=19$m=19456,t=2,p=1$hZHmwKJHGp5XO9/tpqKVRQ$gVxG/noiOPyYVRR4ZByhZ8ITmPHuHzQoBRG7IRGfZ5E"

ph = argon2.PasswordHasher()

try:
    is_valid = ph.verify(generated_hash, "password123")
    print(f"✅ Hash verification: {is_valid}")
    if is_valid:
        print("The hash should work with 'password123'")
    else:
        print("The hash does NOT work with 'password123'")
except Exception as e:
    print(f"❌ Error: {e}")