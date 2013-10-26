<<

function unpack_image(name, width, height,
                      rects, pixels,
                      alpha_rects, alpha_pixels)
    local black_pixel = 'attacks/blank-attack.png~CROP(5,5,1,1)'

    local image_path = 
        string.format('attacks/blank-attack.png~O(0%%)~SCALE(%i,%i)',
                      width, height) 

    for i = 0,((#rects / 7) - 1) do
        local index  = i * 7 + 1
        local x      = rects[index]
        local y      = rects[index + 1]
        local width  = rects[index + 2]
        local height = rects[index + 3]
        local red    = rects[index + 4]
        local green  = rects[index + 5]
        local blue   = rects[index + 6]

        image_path = image_path
            .. string.format('~BLIT(%s~SCALE(%i,%i)~CS(%i,%i,%i),%i,%i)',
                             black_pixel, width, height, red, green, blue,
                             x, y)
    end

    for i = 0,((#alpha_rects / 8) - 1) do
        local index   = i * 8 + 1
        local x       = alpha_rects[index]
        local y       = alpha_rects[index + 1]
        local width   = alpha_rects[index + 2]
        local height  = alpha_rects[index + 3]
        local red     = alpha_rects[index + 4]
        local green   = alpha_rects[index + 5]
        local blue    = alpha_rects[index + 6]
        local opacity = alpha_rects[index + 7]
    
        image_path = image_path
            .. string.format('~BLIT(%s~SCALE(%i,%i)~CS(%i,%i,%i)~O(%i%%),%i,%i)',
                             black_pixel, width, height, red, green, blue,
                             opacity, x, y)
    end

    for i = 0,((#pixels / 5) - 1) do
        local index   = i * 5 + 1
        local x       = pixels[index]
        local y       = pixels[index + 1]
        local red     = pixels[index + 2]
        local green   = pixels[index + 3]
        local blue    = pixels[index + 4]

        image_path = image_path
            .. string.format('~BLIT(%s~CS(%i,%i,%i),%i,%i)',
                             black_pixel, red, green, blue, x, y)
    end

    for i = 0,((#alpha_pixels / 6) - 1) do
        local index   = i * 6 + 1
        local x       = alpha_pixels[index]
        local y       = alpha_pixels[index + 1]
        local red     = alpha_pixels[index + 2]
        local green   = alpha_pixels[index + 3]
        local blue    = alpha_pixels[index + 4]
        local opacity = alpha_pixels[index + 5]

        image_path = image_path
            .. string.format('~BLIT(%s~CS(%i,%i,%i)~O(%i%%),%i,%i)',
                             black_pixel, red, green, blue, opacity, x, y)
    end

    wesnoth.set_variable("image_" .. name, image_path)
end

>>
