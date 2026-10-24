"""Optional pyatv comparison: first authentication request only, no audio or secrets."""
import argparse
import asyncio
import time

from pyatv.support.http import http_connect


async def compare(host, profile, info_first):
    connection = await asyncio.wait_for(http_connect(host, 7000), timeout=5)
    started = time.monotonic()
    try:
        if info_first:
            info = await connection.send_and_receive("GET", "/info", protocol="RTSP/1.0", headers={
                "CSeq": 1, "User-Agent": "AirPlay/550.10", "Content-Length": 0,
            })
            print(f"info status={info.code} cseq={info.headers.get('CSeq')}")
        headers = {
            "User-Agent": "AirPlay/320.20", "Connection": "keep-alive",
            "X-Apple-HKP": 4, "Content-Type": "application/octet-stream",
        }
        if profile != "pyatv":
            headers.update({"User-Agent": "AirPlay/550.10", "CSeq": 2, "Content-Length": 0})
            if profile == "native":
                del headers["Connection"]
        response = await connection.post("/pair-pin-start", headers=headers)
        print(f"profile={profile} pair-pin-start status={response.code} cseq={response.headers.get('CSeq')} elapsed={time.monotonic() - started:.2f}s")
    finally:
        connection.close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host", required=True)
    parser.add_argument("--profile", choices=("pyatv", "native", "native-keepalive"), default="pyatv")
    parser.add_argument("--info-first", action="store_true")
    args = parser.parse_args()
    asyncio.run(compare(args.host, args.profile, args.info_first))
