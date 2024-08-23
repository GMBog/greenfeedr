# Create the logo for the package

library(hexSticker)
library(magick)
library(showtext)

# Read and process the image
img <- magick::image_read("~/Downloads/Picture1.png")
img_resized <- magick::image_resize(img, "150%")
img_transparent <- magick::image_transparent(img_resized, color = "white", fuzz = 10)

# Save the sticker image in your package's man/figures directory
image_path <- file.path("man", "figures", "GFSticker.png")
magick::image_write(img_transparent, path = image_path)

## Loading Google fonts (http://www.google.com/fonts)
font_add_google("Denk One")

## Automatically use showtext to render text for future devices
showtext_auto()

# Create the sticker
sticker(
  subplot = img_transparent,
  package = "greenfeedr",
  p_size = 15,
  p_y = 0.5,
  s_x = 1,
  s_y = 1.15,
  s_width = 1.12,
  s_height = 1.12,
  h_color = "#33691E",
  h_fill = "white", # White background
  p_color = "#33691E",
  p_family = "Denk One",
  filename = image_path # Save sticker in the same path
)
