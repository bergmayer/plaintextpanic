#!/usr/bin/env python3
"""
Generate macOS app icons with the correct squircle (superellipse) shape.

Apple's macOS icon shape is a "squircle" - a superellipse that provides
continuous curvature corners. This script applies that mask to ensure
icons look correct even when the system mask isn't applied.

Usage:
    python3 generate_icons.py [source_image.png]

If no source image is provided, uses icon_512x512@2x.png from the asset catalog.
"""

import math
import os
import sys
from pathlib import Path

try:
    from PIL import Image, ImageDraw
except ImportError:
    print("Error: Pillow is required. Install with: pip3 install Pillow")
    sys.exit(1)


def create_squircle_mask(size, smoothness=5):
    """
    Create a macOS-style squircle mask using superellipse formula.

    The superellipse formula: |x/a|^n + |y/b|^n = 1
    where n (smoothness) ≈ 5 gives the macOS/iOS squircle shape.

    Args:
        size: Width/height of the mask (square)
        smoothness: Superellipse exponent (5 = macOS squircle)

    Returns:
        PIL Image in mode 'L' (grayscale) to use as alpha mask
    """
    mask = Image.new('L', (size, size), 0)

    center = size / 2
    radius = size / 2

    for y in range(size):
        for x in range(size):
            # Normalize coordinates to -1 to 1 range
            nx = (x - center) / radius
            ny = (y - center) / radius

            # Superellipse formula: |x|^n + |y|^n <= 1 means inside
            # Using smoothness=5 for macOS squircle
            value = abs(nx) ** smoothness + abs(ny) ** smoothness

            if value <= 1:
                # Inside the squircle - calculate anti-aliasing
                # Distance from edge for smooth anti-aliasing
                edge_distance = 1 - value
                if edge_distance > 0.02:
                    mask.putpixel((x, y), 255)
                else:
                    # Anti-alias the edge
                    alpha = int(255 * (edge_distance / 0.02))
                    mask.putpixel((x, y), alpha)

    return mask


def create_squircle_mask_fast(size, smoothness=5):
    """
    Faster version using numpy-style operations via PIL.
    Falls back to slow method if needed.
    """
    try:
        import numpy as np

        # Create coordinate grids
        y_coords, x_coords = np.ogrid[:size, :size]

        center = size / 2
        radius = size / 2

        # Normalize to -1 to 1
        nx = (x_coords - center) / radius
        ny = (y_coords - center) / radius

        # Superellipse formula
        value = np.abs(nx) ** smoothness + np.abs(ny) ** smoothness

        # Create mask with anti-aliasing
        mask_array = np.zeros((size, size), dtype=np.uint8)
        inside = value <= 1

        # Anti-aliasing at edges
        edge_width = 0.02
        edge_zone = (value > 1 - edge_width) & (value <= 1)

        mask_array[inside & ~edge_zone] = 255
        mask_array[edge_zone] = (255 * ((1 - value[edge_zone]) / edge_width)).astype(np.uint8)

        return Image.fromarray(mask_array, mode='L')

    except ImportError:
        # Fall back to pure Python version
        return create_squircle_mask(size, smoothness)


def apply_squircle_mask(image, smoothness=5):
    """
    Apply squircle mask to an image, making corners transparent.

    Args:
        image: PIL Image (will be converted to RGBA)
        smoothness: Superellipse exponent (5 = macOS squircle)

    Returns:
        PIL Image with squircle mask applied
    """
    # Ensure image is square
    size = min(image.size)
    if image.size[0] != image.size[1]:
        # Crop to square from center
        left = (image.size[0] - size) // 2
        top = (image.size[1] - size) // 2
        image = image.crop((left, top, left + size, top + size))

    # Convert to RGBA
    if image.mode != 'RGBA':
        image = image.convert('RGBA')

    # Create and apply mask
    mask = create_squircle_mask_fast(size, smoothness)

    # Apply mask to alpha channel
    r, g, b, a = image.split()
    # Combine existing alpha with squircle mask
    a = Image.composite(a, Image.new('L', (size, size), 0), mask)

    return Image.merge('RGBA', (r, g, b, a))


def generate_icon_set(source_path, output_dir):
    """
    Generate all required macOS icon sizes from a source image.

    Args:
        source_path: Path to source image (should be at least 1024x1024)
        output_dir: Directory to save generated icons
    """
    # Required sizes for macOS app icons
    # Format: (base_size, scale, filename)
    icon_sizes = [
        (16, 1, "icon_16x16.png"),
        (16, 2, "icon_16x16@2x.png"),
        (32, 1, "icon_32x32.png"),
        (32, 2, "icon_32x32@2x.png"),
        (128, 1, "icon_128x128.png"),
        (128, 2, "icon_128x128@2x.png"),
        (256, 1, "icon_256x256.png"),
        (256, 2, "icon_256x256@2x.png"),
        (512, 1, "icon_512x512.png"),
        (512, 2, "icon_512x512@2x.png"),
    ]

    print(f"Loading source image: {source_path}")
    source = Image.open(source_path)

    # Apply squircle mask to source at full resolution
    print("Applying squircle mask...")
    masked_source = apply_squircle_mask(source)

    # Generate each size
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    for base_size, scale, filename in icon_sizes:
        actual_size = base_size * scale
        output_path = output_dir / filename

        # Resize with high-quality resampling
        resized = masked_source.resize((actual_size, actual_size), Image.Resampling.LANCZOS)

        # Save as PNG
        resized.save(output_path, "PNG")
        print(f"  Generated: {filename} ({actual_size}x{actual_size})")

    print(f"\nAll icons generated in: {output_dir}")


def main():
    script_dir = Path(__file__).parent
    asset_dir = script_dir / "PlaintextPanic" / "Assets.xcassets" / "AppIcon.appiconset"

    # Determine source image
    if len(sys.argv) > 1:
        source_path = Path(sys.argv[1])
    else:
        # Try to find highest resolution source
        candidates = [
            script_dir / "icon.png",
            asset_dir / "icon_512x512@2x.png",
            asset_dir / "icon_512x512.png",
        ]
        source_path = None
        for candidate in candidates:
            if candidate.exists():
                source_path = candidate
                break

        if source_path is None:
            print("Error: No source image found.")
            print("Usage: python3 generate_icons.py [source_image.png]")
            sys.exit(1)

    if not source_path.exists():
        print(f"Error: Source image not found: {source_path}")
        sys.exit(1)

    # Generate icons
    generate_icon_set(source_path, asset_dir)

    print("\nNote: The squircle shape uses Apple's superellipse formula (n=5)")
    print("This ensures correct corner radius on all macOS versions.")


if __name__ == "__main__":
    main()
