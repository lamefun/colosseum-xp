import sys
from PIL import Image

path = sys.argv[1]
name = sys.argv[2]

img = Image.open(path)
image_width, image_height = img.size

# (color, marked)
in_pixels=[]

for y in range(0, image_height):
    for x in range(0, image_width):
        red, green, blue, alpha = img.getpixel((x, y))
        opacity = int(round((alpha / 255.0) * 100))
        in_pixels.append(((red, green, blue, opacity), False))

def at(x, y):
    return in_pixels[x + y * image_width]

def mark(x, y):
    global in_pixels
    index = x + y * image_width
    in_pixels[index] = (in_pixels[index][0], True)

# (x, y, color)
out_pixels=[]

# (x, y, image_width, image_height, color)
out_rects=[]

def check_row(x1, x2, y, color):
    for x in range(x1, x2):
        if at(x, y)[0] != color or at(x, y)[1] == True:
            return False
    return True

def check_column(x, y1, y2, color):
    for y in range(y1, y2):
        if at(x, y)[0] != color or at(x, y)[1] == True:
            return False
    return True

def mark_row(x1, x2, y):
    for x in range(x1, x2):
        mark(x, y)

def mark_column(x, y1, y2):
    for y in range(y1, y2):
        mark(x, y)

for x in range(0, image_width):
    for y in range(0, image_height):
        color, marked = at(x, y)

        if not marked:
            rect_x = x
            rect_y = y
            rect_width = 1
            rect_height = 1
            can_increase_image_width = True
            can_increase_image_height = True

            while True:
                if rect_x + rect_width == image_width:
                    can_increase_image_width = False

                if rect_y + rect_height == image_height:
                    can_increase_image_height = False

                if can_increase_image_height and check_row(x, x + rect_width, 
                                                     y + rect_height, color):
                    mark_row(x, x + rect_width, y + rect_height)
                    rect_height += 1
                else:
                    can_increase_image_height = False

                if can_increase_image_width and check_column(x + rect_width, y,
                                                       y + rect_height, color):
                    mark_column(x + rect_width, y, y + rect_height)
                    rect_width += 1
                else:
                    can_increase_image_width = False

                if not can_increase_image_width and not can_increase_image_height:
                    break

            if color[3] != 0:
                if rect_width != 1 or rect_height != 1:
                    out_rects.append((rect_x, rect_y, 
                                      rect_width, rect_height,
                                      color))
                else:
                    out_pixels.append((rect_x, rect_y, color))

rect_items=[]
alpha_rect_items=[]
pixel_items=[]
alpha_pixel_items=[]

for rect in out_rects:
    x, y, width, height, color = rect
    red, green, blue, opacity = color

    if opacity == 100:
        rect_items.append('{0},{1},{2},{3},{4},{5},{6}'.format(
                            x, y, width, height, red, green, blue))
    else:
        alpha_rect_items.append('{0},{1},{2},{3},{4},{5},{6},{7}'.format(
                                 x, y, width, height, red, green, blue,
                                 opacity))

for pixel in out_pixels:
    x, y, color = pixel
    red, green, blue, opacity = color

    if opacity == 100:
        pixel_items.append('{0},{1},{2},{3},{4}'.format(
                             x, y, red, green, blue))
    else:
        alpha_pixel_items.append('{0},{1},{2},{3},{4},{5}'.format(
                                   x, y, red, green, blue, opacity))

print("""
[event]
    name=colosseum prestart
    [lua]
        code=<<unpack_image("{0}", {1}, {2}, {{{3}}}, {{{4}}}, {{{5}}}, {{{6}}})>>
    [/lua]
[/event]
""".format(name, image_width, image_height,
           ',\n'.join(rect_items), ',\n'.join(pixel_items),
           ',\n'.join(alpha_rect_items), ',\n'.join(alpha_pixel_items)))
