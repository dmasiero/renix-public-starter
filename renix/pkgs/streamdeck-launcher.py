import io
import os
import subprocess
import sys
import time
import traceback

import cairosvg
from PIL import Image
from StreamDeck.DeviceManager import DeviceManager
from StreamDeck.ImageHelpers import PILHelper


KITTY = os.environ["STREAMDECK_KITTY"]
TUX_SVG = os.environ["STREAMDECK_TUX_SVG"]
POLL_SECONDS = int(os.environ.get("STREAMDECK_POLL_SECONDS", "5"))
BRIGHTNESS = int(os.environ.get("STREAMDECK_BRIGHTNESS", "30"))


def tux_icon(deck):
    png_bytes = cairosvg.svg2png(url=TUX_SVG, output_width=512, output_height=512)
    with Image.open(io.BytesIO(png_bytes)) as source:
        source = source.convert("RGBA")
        background = Image.new("RGBA", source.size, "#000000")
        background.alpha_composite(source)
        image = PILHelper.create_scaled_image(deck, background.convert("RGB"), margins=[0, 0, 0, 0])
    return PILHelper.to_native_format(deck, image)


def reset_other_keys(deck):
    blank = PILHelper.to_native_format(deck, Image.new("RGB", deck.key_image_format()["size"], "#000000"))
    for key in range(1, deck.key_count()):
        deck.set_key_image(key, blank)


def configure(deck):
    deck.open()
    deck.reset()
    deck.set_brightness(BRIGHTNESS)
    deck.set_key_image(0, tux_icon(deck))
    reset_other_keys(deck)

    def on_key_change(_deck, key, state):
        if key == 0 and state:
            subprocess.Popen([KITTY], start_new_session=True)

    deck.set_key_callback(on_key_change)
    return deck


while True:
    deck = None
    try:
        decks = DeviceManager().enumerate()
        if not decks:
            time.sleep(POLL_SECONDS)
            continue

        deck = configure(decks[0])
        while True:
            time.sleep(60)
    except Exception as exc:
        print(f"streamdeck-launcher: {exc}", file=sys.stderr, flush=True)
        traceback.print_exc()
        time.sleep(POLL_SECONDS)
    finally:
        if deck is not None:
            try:
                deck.reset()
                deck.close()
            except Exception:
                pass
