#!/usr/bin/env python3

import requests
import json
import time

# Configuration
BASE_URL = "http://Ryans-MacBook-Air.local:8080"
USERS_TO_CREATE = [
    {
        "handle": "demo",
        "email": "demo@example.com", 
        "display_name": "Demo User",
        "bio": "Hello from PicShare.",
        "password": "ChangeMe123!"
    },
    {
        "handle": "alice",
        "email": "alice@example.com",
        "display_name": "Alice",
        "bio": "Coffee, photos, and travel.",
        "password": "ChangeMe123!"
    },
    {
        "handle": "bob",
        "email": "bob@example.com",
        "display_name": "Bob",
        "bio": "Street photography enthusiast.",
        "password": "ChangeMe123!"
    },
    {
        "handle": "cora",
        "email": "cora@example.com",
        "display_name": "Cora",
        "bio": "Food, friends, and sunsets.",
        "password": "ChangeMe123!"
    }
]

def create_user(user_data):
    """Create a user using the actual signup endpoint"""
    url = f"{BASE_URL}/users"
    
    payload = {
        "handle": user_data["handle"],
        "email": user_data["email"],
        "display_name": user_data["display_name"],
        "bio": user_data["bio"],
        "password": user_data["password"]
    }
    
    try:
        response = requests.post(url, json=payload, timeout=10)
        
        if response.status_code == 200:
            print(f"✅ Successfully created user: {user_data['email']}")
            return True
        elif response.status_code == 409:
            print(f"ℹ️  User already exists: {user_data['email']}")
            return True
        else:
            print(f"❌ Failed to create user {user_data['email']}: {response.status_code}")
            print(f"   Response: {response.text}")
            return False
            
    except Exception as e:
        print(f"❌ Error creating user {user_data['email']}: {e}")
        return False

def test_login(email, password):
    """Test if a user can login successfully"""
    url = f"{BASE_URL}/auth/login"
    
    payload = {
        "email": email,
        "password": password
    }
    
    try:
        response = requests.post(url, json=payload, timeout=10)
        
        if response.status_code == 200:
            print(f"✅ Login successful for: {email}")
            return True
        else:
            print(f"❌ Login failed for {email}: {response.status_code}")
            print(f"   Response: {response.text}")
            return False
            
    except Exception as e:
        print(f"❌ Error testing login for {email}: {e}")
        return False

def main():
    print("🚀 Starting user creation process...")
    print("=" * 50)
    
    # First, clear any existing rate limits
    print("🧹 Clearing rate limits...")
    clear_rate_limits()
    
    # Create users using the actual signup endpoint
    print("👤 Creating users with proper password hashes...")
    for user in USERS_TO_CREATE:
        create_user(user)
        time.sleep(0.5)  # Small delay between requests
    
    print("\n🔑 Testing logins...")
    for user in USERS_TO_CREATE:
        test_login(user["email"], user["password"])
        time.sleep(0.5)
    
    print("\n🎉 User creation and testing complete!")

def clear_rate_limits():
    """Clear Redis rate limits"""
    import subprocess
    try:
        # Clear all rate limits
        subprocess.run([
            "docker", "exec", "picshare-redis-1", "redis-cli", 
            "keys", "ratelimit:*"
        ], capture_output=True)
        
        subprocess.run([
            "docker", "exec", "picshare-redis-1", "redis-cli", 
            "flushdb"
        ], capture_output=True)
        
        print("✅ Rate limits cleared")
    except Exception as e:
        print(f"⚠️  Could not clear rate limits: {e}")

if __name__ == "__main__":
    main()