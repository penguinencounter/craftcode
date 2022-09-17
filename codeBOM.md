# .codeBOM
file documentation

## A bill of materials format for code.lua
Each line follows this format:
```
<file path>:<file sum>
```

`sum` is defined as:
```
i = 0
bytes = {0, 0, 0, 0, 0, 0, 0, 0}
for each byte in input:
    bytes[i] = (bytes[i] + byte) % 0xff
    i = (i + 1) % 8
build = 0
for each byte in bytes:
    build = (build << 8) + byte
```
