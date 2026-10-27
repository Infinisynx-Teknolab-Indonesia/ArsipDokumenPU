"""Membuat ikon macOS (AppIcon 16-1024 px) dan ikon menu bar dari gambar vektor
sederhana (kotak arsip di ubin ungu). Jalankan ulang bila desain ikon diubah:
    python installer/macos/make_icons.py
"""
import json
import pathlib

from PIL import Image, ImageDraw

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / "installer" / "macos" / "AppIcon.appiconset"
S = 4096  # digambar besar lalu diperkecil (anti-alias)


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def box(draw, ox, oy, size, fill, slot_fill):
    """Kotak arsip: tutup + badan + lubang pegangan. Koordinat relatif 0..1."""
    def r(x0, y0, x1, y1, rad, f):
        draw.rounded_rectangle(
            [ox + x0 * size, oy + y0 * size, ox + x1 * size, oy + y1 * size], radius=rad * size, fill=f)
    r(0.33, 0.13, 0.67, 0.27, 0.04, fill)   # tab tutup
    r(0.13, 0.22, 0.87, 0.40, 0.07, fill)   # tutup
    r(0.20, 0.44, 0.80, 0.90, 0.08, fill)   # badan
    r(0.38, 0.55, 0.62, 0.62, 0.035, slot_fill)  # pegangan


def app_icon() -> Image.Image:
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    # ubin macOS: 824/1024 dengan sudut ~185
    m = int(S * 100 / 1024)
    tile = S - 2 * m
    grad = Image.new("RGBA", (tile, tile))
    top, bottom = (0x5B, 0x4F, 0xE0), (0x2A, 0x2F, 0x8F)
    gd = ImageDraw.Draw(grad)
    for y in range(tile):
        gd.line([(0, y), (tile, y)], fill=lerp(top, bottom, y / tile) + (255,))
    mask = Image.new("L", (tile, tile), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, tile - 1, tile - 1], radius=int(tile * 0.225), fill=255)
    # bayangan halus
    shadow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle([m, m + S * 0.012, m + tile, m + tile + S * 0.012],
                                             radius=int(tile * 0.225), fill=(0, 0, 0, 70))
    img = Image.alpha_composite(img, shadow)
    img.paste(grad, (m, m), mask)
    d = ImageDraw.Draw(img)
    pad = tile * 0.16
    box(d, m + pad, m + pad, tile - 2 * pad, (255, 255, 255, 255), lerp(top, bottom, 0.6) + (255,))
    return img


def tray_template() -> Image.Image:
    """Ikon menu bar macOS (template: hitam + transparan, warna diatur macOS)."""
    n = 1024
    img = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    box(d, 0, 0, n, (0, 0, 0, 255), (0, 0, 0, 0))
    return img.resize((44, 44), Image.LANCZOS)  # 22pt @2x


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    big = app_icon()
    images = []
    for pt in (16, 32, 128, 256, 512):
        for scale in (1, 2):
            px = pt * scale
            name = f"icon_{pt}x{pt}{'@2x' if scale == 2 else ''}.png"
            big.resize((px, px), Image.LANCZOS).save(OUT / name)
            images.append({"size": f"{pt}x{pt}", "idiom": "mac", "filename": name, "scale": f"{scale}x"})
    (OUT / "Contents.json").write_text(json.dumps({"images": images, "info": {"version": 1, "author": "xcode"}}, indent=2))
    big.resize((1024, 1024), Image.LANCZOS).save(ROOT / "installer" / "macos" / "app_icon_1024.png")
    tray_template().save(ROOT / "assets" / "icons" / "tray_icon_mac.png")
    print("Ikon macOS dibuat di", OUT)


if __name__ == "__main__":
    main()
