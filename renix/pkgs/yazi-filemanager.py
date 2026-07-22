import asyncio
import os
import subprocess
import sys

from dbus_next.aio import MessageBus
from dbus_next.service import ServiceInterface, method


YAZI_XDG = os.environ["YAZI_XDG"]
DEFAULT_URI = os.environ["YAZI_DEFAULT_URI"]


class FileManager1(ServiceInterface):
    def __init__(self):
        super().__init__("org.freedesktop.FileManager1")

    def _open(self, uris):
        if not uris:
            uris = [DEFAULT_URI]
        for uri in uris:
            try:
                subprocess.Popen(
                    [YAZI_XDG, uri],
                    start_new_session=True,
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                )
            except OSError as exc:
                print(f"yazi-filemanager: failed to open {uri}: {exc}", file=sys.stderr, flush=True)

    @method()
    def ShowItems(self, uris: "as", startup_id: "s") -> "":
        self._open(uris)

    @method()
    def ShowFolders(self, uris: "as", startup_id: "s") -> "":
        self._open(uris)

    @method()
    def ShowItemProperties(self, uris: "as", startup_id: "s") -> "":
        self._open(uris)


async def main():
    bus = await MessageBus().connect()
    bus.export("/org/freedesktop/FileManager1", FileManager1())
    await bus.request_name("org.freedesktop.FileManager1")
    await asyncio.Event().wait()


asyncio.run(main())
