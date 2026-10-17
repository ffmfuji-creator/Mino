"""生成 Mino 的图标素材（构建时由工作流运行，不需要手动上传图片）。

输出：
  assets/icon/icon.png      1024x1024 完整图标
  assets/icon/icon_fg.png   1024x1024 透明底，安卓自适应图标前景
  assets/icon/splash.png    512x512 透明底，启动页 Logo
  android/app/src/main/res/drawable/ic_stat_mino.png  状态栏通知小图标（白色单色）
"""
import math
import os

from PIL import Image, ImageDraw, ImageFilter

BG = (10, 14, 26)
TRACK = (31, 43, 71)
CYAN = (34, 211, 238)
VIOLET = (139, 92, 246)


def lerp(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def polar(cx, cy, r, deg):
    rad = math.radians(deg)
    return cx + r * math.cos(rad), cy + r * math.sin(rad)


def ring_layer(size, radius, width, sweep=270, mono=None):
    """透明图层上画一个进度环：从 12 点钟方向顺时针 sweep 度，青色渐变到紫色。"""
    ss = 4  # 超采样，抗锯齿
    S = size * ss
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx = cy = S / 2
    r = radius * S
    w = width * S
    box = [cx - r, cy - r, cx + r, cy + r]

    if mono is None:
        d.ellipse(box, outline=TRACK + (255,), width=int(w))

    start = -90
    steps = 360
    for i in range(steps):
        a0 = start + sweep * i / steps
        a1 = start + sweep * (i + 1) / steps + 0.6
        color = mono if mono else lerp(CYAN, VIOLET, i / (steps - 1))
        d.arc(box, a0, a1, fill=color + (255,), width=int(w))

    # 圆头
    for deg, col in ((start, mono or CYAN), (start + sweep, mono or VIOLET)):
        x, y = polar(cx, cy, r - w / 2 + 0.5, deg)
        d.ellipse([x - w / 2, y - w / 2, x + w / 2, y + w / 2], fill=col + (255,))

    # 环头上的亮点
    x, y = polar(cx, cy, r - w / 2 + 0.5, start + sweep)
    dot = w * 0.9
    d.ellipse([x - dot / 2, y - dot / 2, x + dot / 2, y + dot / 2],
              fill=(255, 255, 255, 255))
    # 中心小圆点
    c = w * 0.55
    d.ellipse([cx - c, cy - c, cx + c, cy + c], fill=(mono or CYAN) + (255,))

    return img.resize((size, size), Image.LANCZOS)


def background(size):
    img = Image.new("RGBA", (size, size), BG + (255,))
    glow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    g = ImageDraw.Draw(glow)
    r = size * 0.36
    c = size / 2
    g.ellipse([c - r, c - r, c + r, c + r], fill=VIOLET + (90,))
    glow = glow.filter(ImageFilter.GaussianBlur(size * 0.12))
    return Image.alpha_composite(img, glow)


def main():
    os.makedirs("assets/icon", exist_ok=True)

    # 完整图标
    icon = background(1024)
    icon = Image.alpha_composite(icon, ring_layer(1024, 0.30, 0.075))
    icon.convert("RGB").save("assets/icon/icon.png")

    # 自适应图标前景（内容限制在中间 ~60% 安全区内）
    fg = ring_layer(1024, 0.215, 0.055)
    fg.save("assets/icon/icon_fg.png")

    # 启动页 Logo
    ring_layer(512, 0.34, 0.085).save("assets/icon/splash.png")

    # 状态栏通知图标：白色单色 + 透明
    stat_dir = "android/app/src/main/res/drawable"
    os.makedirs(stat_dir, exist_ok=True)
    stat = ring_layer(96, 0.38, 0.12, mono=(255, 255, 255))
    stat.save(os.path.join(stat_dir, "ic_stat_mino.png"))
    print("icons generated")


if __name__ == "__main__":
    main()
