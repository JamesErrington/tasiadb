from io import BufferedReader
import time

def micro_time():
    return round(time.time_ns() / 1000)

def read_string(file: BufferedReader):
    while file.peek():
        len_bytes = file.read(4)
        length = int.from_bytes(len_bytes, "little")
        str_bytes = file.read(length)
        string = str_bytes.decode("utf-8")
        yield string

entries = {
    "name": "James Errington",
    "country": "United Kingdom",
}

timestamp = micro_time()
with open(f"data/{timestamp}.wal", "wb") as file:
    for k, v in entries.items():
        file.write(len(k).to_bytes(4, "little"))
        file.write(bytes(k, "utf-8"))
        file.write(len(v).to_bytes(4, "little"))
        file.write(bytes(v, "utf-8"))

with open(f"data/{timestamp}.wal", "rb") as file:
    for s in read_string(file):
        print(s)
