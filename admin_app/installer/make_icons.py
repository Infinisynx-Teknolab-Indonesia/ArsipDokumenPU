"""Ikon aplikasi Admin Server (perisai putih di ubin ungu-gelap) untuk Windows (.ico)
dan macOS (AppIcon.appiconset). Jalankan ulang bila desain diubah:
    python admin_app/installer/make_icons.py
"""
import json
import pathlib

from PIL import Image, ImageDraw

HERE = pathlib.Path(__file__).resolve().parent
S = 4096


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def icon(mac: bool) -> Image.Image:
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    m = int(S * (100 / 1024 if mac else 0.02))
    tile = S - 2 * m
    top, bottom = (0x2B, 0x31, 0x9A), (0x14, 0x1B, 0x4D)
    grad = Image.new("RGBA", (tile, tile))
    gd = ImageDraw.Draw(grad)
    for y in range(tile):
        gd.line([(0, y), (tile, y)], fill=lerp(top, bottom, y / tile) + (255,))
    mask = Image.new("L", (tile, tile), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, tile - 1, tile - 1], radius=int(tile * 0.225), fill=255)
    img.paste(grad, (m, m), mask)
    d = ImageDraw.Draw(img)
    cx, cy, w = S / 2, S / 2 + tile * 0.02, tile * 0.52
    # perisai
    top_y, mid_y, bot_y = cy - w * 0.62, cy + w * 0.05, cy + w * 0.72
    d.polygon([(cx - w / 2, top_y + w * 0.12), (cx, top_y), (cx + w / 2, top_y + w * 0.12),
               (cx + w / 2, mid_y), (cx, bot_y), (cx - w / 2, mid_y)], fill=(255, 255, 255, 255))
    # tanda centang ungu
    accent = (0x5B, 0x4F, 0xE0, 255)
    lw = int(w * 0.11)
    d.line([(cx - w * 0.2, cy + w * 0.0), (cx - w * 0.04, cy + w * 0.17), (cx + w * 0.23, cy - w * 0.17)], fill=accent, width=lw, joint="curve")
    return img


def main():
    win = icon(False)
    win.save(HERE / "app_icon.ico", sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
    big = icon(True)
    out = HERE / "macos" / "AppIcon.appiconset"
    out.mkdir(parents=True, exist_ok=True)
    images = []
    for pt in (16, 32, 128, 256, 512):
        for scale in (1, 2):
            px = pt * scale
            name = f"icon_{pt}x{pt}{'@2x' if scale == 2 else ''}.png"
            big.resize((px, px), Image.LANCZOS).save(out / name)
            images.append({"size": f"{pt}x{pt}", "idiom": "mac", "filename": name, "scale": f"{scale}x"})
    (out / "Contents.json").write_text(json.dumps({"images": images, "info": {"version": 1, "author": "xcode"}}, indent=2))
    big.resize((256, 256), Image.LANCZOS).save(HERE / "preview.png")
    print("ikon admin dibuat")


if __name__ == "__main__":
    main()
