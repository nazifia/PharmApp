#!/usr/bin/env python3
"""
Script to generate PWA icons from base SVG
"""
import os
from PIL import Image, ImageDraw

def create_pharmacy_icon(size, output_path):
    """Create a pharmacy-themed icon"""
    # Create a new image
    img = Image.new('RGB', (size, size), color=(66, 133, 244))  # Blue background
    draw = ImageDraw.Draw(img)
    
    # Draw a simple cross (pharmacy symbol)
    cross_color = (255, 255, 255)  # White cross
    cross_width = size // 8
    cross_length = size // 2
    
    # Vertical bar
    x1 = (size - cross_width) // 2
    y1 = (size - cross_length) // 2
    x2 = x1 + cross_width
    y2 = y1 + cross_length
    draw.rectangle([x1, y1, x2, y2], fill=cross_color)
    
    # Horizontal bar
    x1 = (size - cross_length) // 2
    y1 = (size - cross_width) // 2
    x2 = x1 + cross_length
    y2 = y1 + cross_width
    draw.rectangle([x1, y1, x2, y2], fill=cross_color)
    
    img.save(output_path)
    print(f"Created pharmacy icon: {output_path}")

def main():
    static_dir = os.path.join('static', 'img')
    
    # Ensure the directory exists
    os.makedirs(static_dir, exist_ok=True)
    
    # Icon sizes needed for PWA
    sizes = [72, 96, 128, 144, 152, 192, 384, 512]
    
    # Create icons for each size
    for size in sizes:
        output_path = os.path.join(static_dir, f'icon-{size}x{size}.png')
        if not os.path.exists(output_path):
            try:
                create_pharmacy_icon(size, output_path)
                print(f"Generated icon: {size}x{size}")
            except Exception as e:
                print(f"Error creating icon {size}x{size}: {e}")
        else:
            print(f"Icon already exists: {size}x{size}")

if __name__ == "__main__":
    main()