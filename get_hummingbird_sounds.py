#!/usr/bin/env python3
"""
Script to help download hummingbird sounds for the ZippUp app.
Run this script to get real hummingbird audio files.
"""

import os
import urllib.request
import ssl

def download_hummingbird_sounds():
    """Download hummingbird sounds from free sources"""
    sounds_dir = "assets/sounds"
    
    # Create SSL context that doesn't verify certificates (for freesound.org)
    ssl_context = ssl.create_default_context()
    ssl_context.check_hostname = False
    ssl_context.verify_mode = ssl.CERT_NONE
    
    # Free hummingbird sounds (these are example URLs - you'll need to find actual free sounds)
    sounds = {
        "hummingbird_chirp.mp3": "https://www.soundjay.com/misc/sounds/bell-ringing-05.mp3",  # Placeholder
        "hummingbird_call.mp3": "https://www.soundjay.com/misc/sounds/bell-ringing-04.mp3",   # Placeholder  
        "hummingbird_trill.mp3": "https://www.soundjay.com/misc/sounds/bell-ringing-03.mp3"  # Placeholder
    }
    
    print("🐦 Downloading hummingbird sounds for ZippUp notifications...")
    print("\nNote: The URLs below are placeholders. Please replace with actual hummingbird sound URLs.")
    print("Recommended sources:")
    print("- https://freesound.org (search for 'hummingbird')")
    print("- https://zapsplat.com (requires free account)")
    print("- https://pixabay.com/sound-effects/search/hummingbird/")
    print("- https://mixkit.co/free-sound-effects/")
    
    for filename, url in sounds.items():
        filepath = os.path.join(sounds_dir, filename)
        print(f"\n📥 Would download: {filename}")
        print(f"   URL: {url}")
        print(f"   To: {filepath}")
        
        # Uncomment the lines below when you have real URLs
        # try:
        #     urllib.request.urlretrieve(url, filepath)
        #     print(f"✅ Downloaded: {filename}")
        # except Exception as e:
        #     print(f"❌ Failed to download {filename}: {e}")
    
    print(f"\n🎵 Manual steps:")
    print(f"1. Visit the recommended sources above")
    print(f"2. Search for 'hummingbird' sounds")
    print(f"3. Download 3 different sounds:")
    print(f"   - Short chirp (1-2 seconds) for general notifications")
    print(f"   - Longer call (3-4 seconds) for urgent ride requests") 
    print(f"   - Gentle trill (2-3 seconds) for completion notifications")
    print(f"4. Rename them to match the filenames above")
    print(f"5. Place them in the {sounds_dir} directory")
    print(f"\n🔧 The app will work with placeholder sounds, but real sounds will improve UX!")

if __name__ == "__main__":
    download_hummingbird_sounds()