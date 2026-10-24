"""Optional finite pyatv tone comparison; never captures audio or saves credentials."""
import argparse
import asyncio
import math
from pathlib import Path
import struct
import tempfile
import wave

import pyatv
from pyatv.const import Protocol


async def compare(host, name):
    loop = asyncio.get_running_loop()
    devices = await pyatv.scan(loop, hosts=[host], protocol=Protocol.RAOP, timeout=5)
    matches = [device for device in devices if device.name == name]
    if len(matches) != 1:
        raise RuntimeError("The selected receiver was not uniquely discovered; stopping.")
    with tempfile.TemporaryDirectory(prefix="podcast-tone-") as directory:
        tone = Path(directory) / "synthetic.wav"
        with wave.open(str(tone), "wb") as output:
            output.setparams((2, 2, 44100, 0, "NONE", "not compressed"))
            frames = bytearray()
            for index in range(5 * 44100):
                at = index / 44100
                envelope = min(1, at / .02, (5 - at) / .02)
                sample = round(32767 * .05 * envelope * math.sin(2 * math.pi * 440 * at))
                frames.extend(struct.pack("<hh", sample, sample))
            output.writeframes(frames)
        device = await pyatv.connect(matches[0], loop, protocol=Protocol.RAOP)
        try:
            await device.audio.set_volume(38)
            print("Sending five seconds of synthetic tone at peak0.05; receiver volume38.", flush=True)
            await device.stream.stream_file(str(tone))
            print("Stream procedure completed; audible confirmation is still required.")
        finally:
            await asyncio.gather(*device.close())


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host", required=True)
    parser.add_argument("--name", required=True)
    args = parser.parse_args()
    asyncio.run(asyncio.wait_for(compare(args.host, args.name), timeout=45))
