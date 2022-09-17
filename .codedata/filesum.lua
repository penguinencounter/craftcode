local quicksum = require "quicksum"

print("Filesum - quick file quicksum calculation utility")

local args = {...}
local file = args[1]

if not file then
    print("Usage: filesum <file>")
    return
end

local f = fs.open(file, "r")
local data = f.readAll()
f.close()

print("Finished")
print(quicksum.sum(data))
