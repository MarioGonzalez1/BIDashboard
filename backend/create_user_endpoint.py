#!/usr/bin/env python3
"""
Temporary script to create Mario Gonzalez user via FastAPI backend
"""

import requests
import bcrypt
import json

def create_user_via_api():
    """Create user via the existing FastAPI backend"""
    
    # Backend API URL
    api_base_url = "http://localhost:8000"
    
    # User data
    user_data = {
        "username": "mario.gonzalez",
        "email": "mario.gonzalez@forzatrans.com",
        "password": "ChangeMe2024!",  # Temporary password
        "first_name": "Mario",
        "last_name": "Gonzalez",
        "is_admin": True
    }
    
    print("🚀 Creating user via FastAPI backend...")
    print(f"📡 API URL: {api_base_url}")
    print(f"👤 Username: {user_data['username']}")
    print(f"📧 Email: {user_data['email']}")
    
    try:
        # Try to create user via API
        response = requests.post(f"{api_base_url}/auth/register", json=user_data, timeout=10)
        
        if response.status_code == 200 or response.status_code == 201:
            result = response.json()
            print("✅ User created successfully!")
            print(f"📋 Response: {json.dumps(result, indent=2)}")
            return True
        else:
            print(f"❌ API Error: {response.status_code}")
            print(f"📋 Response: {response.text}")
            return False
            
    except requests.exceptions.ConnectionError:
        print("❌ Connection Error: Backend server not running")
        print("💡 Start the backend server first with: uvicorn main:app --reload")
        return False
    except requests.exceptions.Timeout:
        print("❌ Timeout Error: Request took too long")
        return False
    except Exception as e:
        print(f"❌ Unexpected error: {e}")
        return False

if __name__ == "__main__":
    print("🔧 Creating user via FastAPI backend...")
    print("="*50)
    
    success = create_user_via_api()
    
    if success:
        print("\n🎉 User creation completed!")
        print("\n📋 Login Credentials:")
        print("   👤 Username: mario.gonzalez")
        print("   📧 Email: mario.gonzalez@forzatrans.com") 
        print("   🔐 Password: ChangeMe2024!")
        print("\n⚠️  IMPORTANT: Change password after first login!")
    else:
        print("\n❌ User creation failed")
        print("\n💡 Alternative: Run the SQL script manually:")
        print("   📁 File: backend/database/create_user_mario.sql")
    
    print("="*50)