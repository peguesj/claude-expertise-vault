#!/usr/bin/env python3
"""
Scrape and download images from expert posts.

Reads raw JSONL data, extracts image URLs from media fields,
and downloads them to data/images/{author}/{post_id}/.

Usage:
    python scripts/scrape_images.py --author mitko-vasilev
    python scripts/scrape_images.py --author mitko-vasilev --rescrape
    python scripts/scrape_images.py --scan-linkedin  # re-scan LinkedIn for media URLs
"""

import json
import argparse
import hashlib
import re
import urllib.request
import urllib.error
import ssl
import time
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor, as_completed

BASE_DIR = Path(__file__).resolve().parent.parent
RAW_DIR = BASE_DIR / "data" / "raw"
IMAGES_DIR = BASE_DIR / "data" / "images"

# SSL context that doesn't verify (for LinkedIn CDN)
SSL_CTX = ssl.create_default_context()
SSL_CTX.check_hostname = False
SSL_CTX.verify_mode = ssl.CERT_NONE

USER_AGENT = (
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) "
    "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
)


def download_image(url: str, dest: Path, timeout: int = 30) -> bool:
    """Download an image from URL to destination path."""
    if dest.exists() and dest.stat().st_size > 0:
        return True  # Already downloaded

    dest.parent.mkdir(parents=True, exist_ok=True)

    try:
        req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
        with urllib.request.urlopen(req, timeout=timeout, context=SSL_CTX) as resp:
            content = resp.read()
            if len(content) < 100:
                return False  # Too small, likely an error page
            dest.write_bytes(content)
            return True
    except (urllib.error.URLError, TimeoutError, OSError) as e:
        print(f"  Failed to download {url}: {e}")
        return False


def extract_image_urls_from_text(text: str) -> list[str]:
    """Extract image URLs embedded in post text (markdown, bare URLs)."""
    patterns = [
        r'https?://[^\s<>"]+\.(?:jpg|jpeg|png|gif|webp|avif)(?:\?[^\s<>"]*)?',
        r'https?://media\.licdn\.com/[^\s<>"]+',
        r'https?://pbs\.twimg\.com/[^\s<>"]+',
    ]
    urls = set()
    for p in patterns:
        urls.update(re.findall(p, text, re.IGNORECASE))
    return list(urls)


def url_to_filename(url: str) -> str:
    """Generate a deterministic filename from a URL."""
    # Try to preserve original extension
    path_part = url.split("?")[0]
    ext = Path(path_part).suffix.lower()
    if ext not in (".jpg", ".jpeg", ".png", ".gif", ".webp", ".avif"):
        ext = ".jpg"
    url_hash = hashlib.sha256(url.encode()).hexdigest()[:12]
    return f"{url_hash}{ext}"


def scrape_author_images(author: str, rescrape: bool = False) -> dict:
    """Download all images for an author's posts."""
    raw_path = RAW_DIR / f"{author}.jsonl"
    if not raw_path.exists():
        print(f"Error: {raw_path} not found")
        return {"downloaded": 0, "skipped": 0, "failed": 0}

    author_dir = IMAGES_DIR / author
    author_dir.mkdir(parents=True, exist_ok=True)

    # Track what we need to download
    downloads = []  # (url, dest_path, post_id)
    stats = {"downloaded": 0, "skipped": 0, "failed": 0, "posts_with_images": 0}

    # Also build updated media mapping
    media_mapping = {}  # post_id -> [local_paths]

    with open(raw_path, "r") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            post = json.loads(line)
            post_id = post["id"]
            post_dir = author_dir / post_id

            # Collect image URLs from explicit media field and text
            image_urls = list(post.get("media", []))
            image_urls.extend(extract_image_urls_from_text(post.get("text", "")))

            # Deduplicate
            image_urls = list(dict.fromkeys(image_urls))

            if not image_urls:
                continue

            stats["posts_with_images"] += 1
            local_paths = []

            for url in image_urls:
                filename = url_to_filename(url)
                dest = post_dir / filename
                local_paths.append(str(dest.relative_to(BASE_DIR)))

                if not rescrape and dest.exists() and dest.stat().st_size > 0:
                    stats["skipped"] += 1
                    continue

                downloads.append((url, dest, post_id))

            media_mapping[post_id] = local_paths

    if not downloads:
        print(f"No new images to download for {author}")
        if media_mapping:
            _save_media_mapping(author, media_mapping)
        return stats

    print(f"Downloading {len(downloads)} images for {author}...")

    # Parallel download with rate limiting
    with ThreadPoolExecutor(max_workers=4) as executor:
        futures = {}
        for url, dest, post_id in downloads:
            future = executor.submit(download_image, url, dest)
            futures[future] = (url, dest, post_id)
            time.sleep(0.2)  # Rate limit

        for future in as_completed(futures):
            url, dest, post_id = futures[future]
            if future.result():
                stats["downloaded"] += 1
                print(f"  [{post_id}] {dest.name}")
            else:
                stats["failed"] += 1

    _save_media_mapping(author, media_mapping)
    return stats


def _save_media_mapping(author: str, mapping: dict):
    """Save the post_id -> local_image_paths mapping."""
    map_path = IMAGES_DIR / author / "media_mapping.json"
    map_path.parent.mkdir(parents=True, exist_ok=True)
    with open(map_path, "w") as f:
        json.dump(mapping, f, indent=2)
    print(f"  Media mapping saved: {map_path}")


def update_raw_with_media(author: str):
    """Update raw JSONL to include media URLs discovered from scraping.

    This is a non-destructive operation that adds a 'media' field to posts
    that had image URLs detected in their text.
    """
    raw_path = RAW_DIR / f"{author}.jsonl"
    if not raw_path.exists():
        return

    posts = []
    updated = 0
    with open(raw_path, "r") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            post = json.loads(line)
            text_urls = extract_image_urls_from_text(post.get("text", ""))
            existing_media = post.get("media", [])
            all_media = list(dict.fromkeys(existing_media + text_urls))
            if all_media and all_media != existing_media:
                post["media"] = all_media
                updated += 1
            posts.append(post)

    if updated > 0:
        with open(raw_path, "w") as f:
            for post in posts:
                f.write(json.dumps(post) + "\n")
        print(f"Updated {updated} posts with media URLs in {raw_path.name}")


def main():
    parser = argparse.ArgumentParser(description="Download images from expert posts")
    parser.add_argument("--author", default="mitko-vasilev", help="Author slug")
    parser.add_argument("--rescrape", action="store_true", help="Re-download existing images")
    parser.add_argument("--update-raw", action="store_true",
                        help="Update raw JSONL with discovered media URLs")
    args = parser.parse_args()

    if args.update_raw:
        update_raw_with_media(args.author)

    stats = scrape_author_images(args.author, rescrape=args.rescrape)

    print(f"\nImage scraping complete for {args.author}:")
    print(f"  Downloaded: {stats['downloaded']}")
    print(f"  Skipped (existing): {stats['skipped']}")
    print(f"  Failed: {stats['failed']}")
    print(f"  Posts with images: {stats['posts_with_images']}")


if __name__ == "__main__":
    main()
