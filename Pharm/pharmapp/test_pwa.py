#!/usr/bin/env python3
"""
Test script for PWA functionality
"""
import os
import json

def test_manifest():
    """Test if manifest.json has required properties"""
    manifest_path = os.path.join('static', 'manifest.json')
    
    if not os.path.exists(manifest_path):
        print("❌ manifest.json not found")
        return False
    
    try:
        with open(manifest_path, 'r') as f:
            manifest = json.load(f)
        
        required_fields = ['name', 'short_name', 'start_url', 'display', 'background_color', 'theme_color']
        missing_fields = [field for field in required_fields if field not in manifest]
        
        if missing_fields:
            print(f"❌ Missing required fields in manifest.json: {missing_fields}")
            return False
        
        # Check if icons exist
        if 'icons' not in manifest:
            print("❌ No icons defined in manifest.json")
            return False
        
        print("✅ manifest.json validation passed")
        return True
    except Exception as e:
        print(f"❌ Error validating manifest.json: {e}")
        return False

def test_service_worker():
    """Test if service worker exists"""
    sw_path = os.path.join('static', 'js', 'sw.js')
    
    if not os.path.exists(sw_path):
        print("❌ Service worker (sw.js) not found")
        return False
    
    print("✅ Service worker found")
    return True

def test_icons():
    """Test if required icons exist"""
    required_icons = [
        'icon-72x72.png',
        'icon-96x96.png',
        'icon-128x128.png',
        'icon-144x144.png',
        'icon-152x152.png',
        'icon-192x192.png',
        'icon-384x384.png',
        'icon-512x512.png'
    ]
    
    missing_icons = []
    for icon in required_icons:
        icon_path = os.path.join('static', 'img', icon)
        if not os.path.exists(icon_path):
            missing_icons.append(icon)
    
    if missing_icons:
        print(f"❌ Missing icons: {missing_icons}")
        return False
    
    print("✅ All required icons found")
    return True

def test_offline_page():
    """Test if offline page exists"""
    offline_path = os.path.join('templates', 'offline.html')
    
    if not os.path.exists(offline_path):
        print("❌ Offline page (offline.html) not found")
        return False
    
    print("✅ Offline page found")
    return True

def main():
    """Run all PWA tests"""
    print("🧪 Testing PWA Implementation...")
    print("=" * 40)
    
    tests = [
        test_manifest,
        test_service_worker,
        test_icons,
        test_offline_page
    ]
    
    passed = 0
    for test in tests:
        if test():
            passed += 1
    
    print("=" * 40)
    print(f"✅ {passed}/{len(tests)} tests passed")
    
    if passed == len(tests):
        print("🎉 All PWA tests passed! Your application is ready for PWA features.")
    else:
        print("⚠️  Some tests failed. Please check the issues above.")

if __name__ == "__main__":
    main()