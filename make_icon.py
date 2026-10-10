from PIL import Image, ImageDraw, ImageFont
import math

def draw_icon(size):
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    s = size

    # Fondo degradado azul (simulado con rectángulo redondeado)
    radius = int(s * 0.22)
    for y in range(s):
        t = y / s
        r = int(107 + (27 - 107) * t)
        g = int(186 + (98 - 186) * t)
        b = int(248 + (204 - 248) * t)
        # solo dibujar dentro del rounded rect
        for x in range(s):
            # check rounded corners
            in_rect = True
            if x < radius and y < radius:
                in_rect = math.sqrt((x-radius)**2 + (y-radius)**2) <= radius
            elif x > s-radius and y < radius:
                in_rect = math.sqrt((x-(s-radius))**2 + (y-radius)**2) <= radius
            elif x < radius and y > s-radius:
                in_rect = math.sqrt((x-radius)**2 + (y-(s-radius))**2) <= radius
            elif x > s-radius and y > s-radius:
                in_rect = math.sqrt((x-(s-radius))**2 + (y-(s-radius))**2) <= radius
            if in_rect:
                img.putpixel((x, y), (r, g, b, 255))

    # Cuerpo blanco de la tienda
    bx1, by1 = int(s*0.20), int(s*0.46)
    bx2, by2 = int(s*0.80), int(s*0.88)
    d.rounded_rectangle([bx1, by1, bx2, by2], radius=int(s*0.04), fill=(255,255,255,255))

    # Techo rojo
    rx = [int(s*0.18), int(s*0.82), int(s*0.75), int(s*0.25)]
    ry = [int(s*0.47), int(s*0.47), int(s*0.29), int(s*0.29)]
    d.polygon(list(zip(rx, ry)), fill=(240, 78, 106, 255))

    # Franjas blancas en techo
    for i in range(6):
        t = 0.27 + i * 0.095
        x_top = int(s * t)
        x_bot = int(s * (t - 0.06))
        d.line([(x_top, int(s*0.29)), (x_bot, int(s*0.47))],
               fill=(255,255,255,60), width=max(1, int(s*0.04)))

    # Círculo azul
    cx, cy, cr = int(s*0.5), int(s*0.60), int(s*0.16)
    d.ellipse([cx-cr, cy-cr, cx+cr, cy+cr], fill=(30, 136, 229, 255))

    # Texto </> en el círculo
    try:
        font_size = max(8, int(s * 0.11))
        font = ImageFont.truetype("C:/Windows/Fonts/cour.ttf", font_size)
    except:
        font = ImageFont.load_default()

    text = "</>"
    bbox = d.textbbox((0,0), text, font=font)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    d.text((cx - tw//2, cy - th//2), text, fill=(255,255,255,255), font=font)

    # Puerta
    dx1, dy1 = int(s*0.41), int(s*0.74)
    dx2, dy2 = int(s*0.59), int(s*0.88)
    d.rounded_rectangle([dx1, dy1, dx2, dy2], radius=int(s*0.02), fill=(221, 238, 255, 255))

    return img

sizes = [16, 32, 48, 64, 128, 256]
imgs = [draw_icon(s) for s in sizes]

imgs[-1].save(
    r'windows\runner\resources\app_icon.ico',
    format='ICO',
    sizes=[(s, s) for s in sizes],
    append_images=imgs[:-1]
)
print('ICO generado correctamente')
