local export = {}
export.sum = function(data)
    -- Want to sum your own files? Do this:
    local i = 0
    local b = {0, 0, 0, 0}
    for c in data:gmatch(".") do
        b[i+1] = (b[i+1] + c:byte()) % 0xff
        i = (i + 1) % #b
    end
    i = 0
    for _, v in ipairs(b) do
        i = (i * (2^8)) + v
    end
    return i
end

export.validateBOM = function(rootWorkingDir)
    local f = fs.open(rootWorkingDir..".codeBOM", "r")
    local bom = f.readAll()
    local ok = true
    f.close()
    for line in bom:gmatch("[^\r\n]+") do
        local file, sum = line:match("^([^:]+):([^:]+)$")
        if file and sum and #file ~= 0 then
            local f2 = fs.open(rootWorkingDir..file, "r")
            if f2 == nil then
                print("Checksum failed: file missing: " .. file)
                ok = false
            else
                local data = f2.readAll()
                f2.close()
                local actual = export.sum(data)
                local expected = tonumber(sum)
                if actual ~= expected then
                    print("Checksum mismatch for " .. file .. ":")
                    print("    Expected: " .. expected)
                    print("    Actual: " .. actual)
                    ok = false
                end
            end
        end
    end
    return ok
end

return export