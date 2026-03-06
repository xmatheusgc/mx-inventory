// Use import.meta.glob to eagerly import all images from the assets directory.
// This ensures Vite bundles them and provides a map of original paths to hashed URLs.
const assetsImages = import.meta.glob<{ default: string }>('../assets/images/*.{png,PNG,jpg,jpeg,svg,webp}', {
    eager: true,
});

/**
 * Resolves an image URL for the inventory items.
 * Handles both public static assets and src/assets images.
 */
export const getImageUrl = (imageName?: string): string => {
    if (!imageName) return '';

    // Ignore already resolved URLs
    if (imageName.startsWith('http') || imageName.startsWith('blob:') || imageName.startsWith('data:')) {
        return imageName;
    }

    // Clean up the imageName (remove common path prefixes if present)
    let cleanName = imageName.replace(/^(items\/|images\/|\.\/items\/|\.\/images\/)/, '');

    // Try to resolve from mapped assets
    // Glob keys usually look like '../assets/images/pistol.png' relative to this file
    const assetPath = `../assets/images/${cleanName}`;
    const asset = assetsImages[assetPath];

    if (asset) {
        return asset.default;
    }

    // Fallback to legacy path if not found in assets
    // Note: In NUI, relative paths depend on the index.html location
    return `./items/${cleanName}`;
};

// For debugging in NUI DevTools
(window as any).__getImageUrl = getImageUrl;
(window as any).__assetsImages = assetsImages;
