--[[
    code - an advanced text editor for ComputerCraft
]]--
package.path = package.path .. ";.codedata/?.lua"

local quicksum = require "quicksum"

local args = {...}

local file = args[1]

local cwd = shell.dir()
if cwd ~= "/" then cwd = cwd .. "/" end

local function validate()
    local codeBomFile = fs.exists(cwd .. ".codeBOM")
    local isSourceValid = not codeBomFile or quicksum.validateBOM(cwd)

    if not isSourceValid then
        printError("code: source is invalid\n    redownload mentioned files, or\n    delete .codeBOM to ignore")
        return false
    elseif not codeBomFile then
        printError("code: (warning) could not find checksum file")
        printError("    code validation could not be performed")
        printError("    searched " .. cwd .. " for .codeBOM file")
        sleep(1)
    end
    return true
end

local function loadInFile()
    if file == nil then
        print("code: no file specified")
        return ""
    end
    local f = fs.open(cwd .. file, "r")
    if f == nil then
        print("code: could not open file " .. file)
        return ""
    end
    local data = f.readAll()
    f.close()
    return data
end

if not validate() then return end
local contents = loadInFile()

print(contents)
