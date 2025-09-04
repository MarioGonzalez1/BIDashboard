#!/usr/bin/env python3
"""
Migration script to import dashboards from db.json to SQLite database
"""

import json
from database_sqlite import SessionLocal, Dashboard, User, pwd_context

def migrate_data():
    """Import dashboards and users from db.json"""
    
    # Load JSON data
    with open('db.json', 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    db = SessionLocal()
    try:
        print("🔄 Starting migration from db.json...")
        
        # Clear existing dashboards first
        db.query(Dashboard).delete()
        print("✅ Cleared existing dashboards")
        
        # Import dashboards
        dashboard_count = 0
        for dashboard_data in data.get('tableros', []):
            dashboard = Dashboard(
                titulo=dashboard_data['titulo'],
                url_acceso=dashboard_data['url_acceso'],
                categoria=dashboard_data['categoria'],
                subcategoria=dashboard_data.get('subcategoria', ''),
                descripcion=dashboard_data.get('descripcion', ''),
                url_imagen_preview=dashboard_data.get('url_imagen_preview', ''),
                created_by=1  # Created by admin user
            )
            db.add(dashboard)
            dashboard_count += 1
        
        # Import additional users (but don't overwrite existing ones)
        user_count = 0
        for user_data in data.get('users', []):
            username = user_data['username']
            existing_user = db.query(User).filter(User.username == username).first()
            
            if not existing_user:
                user = User(
                    username=username,
                    hashed_password=user_data['hashed_password'],
                    is_admin=user_data.get('is_admin', False)
                )
                db.add(user)
                user_count += 1
                print(f"✅ Added user: {username}")
        
        db.commit()
        
        print(f"🎉 Migration completed successfully!")
        print(f"   📊 Imported {dashboard_count} dashboards")
        print(f"   👤 Added {user_count} new users")
        
        # Show dashboard summary
        print(f"\n📋 Dashboard Categories:")
        categories = db.query(Dashboard.categoria).distinct().all()
        for (category,) in categories:
            count = db.query(Dashboard).filter(Dashboard.categoria == category).count()
            print(f"   - {category}: {count} dashboards")
            
    except Exception as e:
        print(f"❌ Migration failed: {e}")
        db.rollback()
    finally:
        db.close()

if __name__ == "__main__":
    migrate_data()