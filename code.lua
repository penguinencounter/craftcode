--[[
    code - an advanced text editor for ComputerCraft
]]--
package.path = package.path .. ";.codedata/?.lua"


local quicksum = require "quicksum"

local args = {...}

local file = args[1]

local DRAWING_CHARS = {
    cross="\x7f"
}

local cwd = shell.dir()
if cwd ~= "/" then cwd = cwd .. "/" end
local lineEndings = "LF"

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
    if file == nil or file == "<new>" then
        print("code: no file specified")
        file = "<new>"
        return true, ""
    end
    local f = fs.open(cwd .. file, "r")
    if f == nil then
        if fs.isDir(cwd .. file) then
            printError("code: " .. file .. " is a directory")
            return false, file.." is a directory"
        end
        print("code: could not open file " .. file)
        return true, ""
    end
    local data = f.readAll()
    f.close()
    return true, data
end

if not validate() then return end

local function recolor(win, newColor, newTColor)
    win.setBackgroundColor(newColor)
    win.setTextColor(newTColor)
    win.clear()
end

local line = 1
local col = 1

local tW, tH = term.getSize()
local editWindow = window.create(term.current(), 1, 2, tW, tH-2)
local topBar = window.create(term.current(), 1, 1, tW, 1)
local bottomBar = window.create(term.current(), 1, tH, tW, 1)

EditorConf = {
    gutterBG = colors.black,
    gutterFG = colors.gray,
    mainBG = colors.black,
    mainFG = colors.white,
}

local function drawInitial(win, data)
    win.clear()
    local w, h = win.getSize()
    local lineCount = 0
    win.setCursorPos(1, 1)
    for _ in data:gmatch("\n") do lineCount = lineCount + 1 end
    local function writeGutter(line)
        win.setBackgroundColor(EditorConf.gutterBG)
        win.setTextColor(EditorConf.gutterFG)
        win.write(" ")
        win.write((" "):rep(#(""..lineCount)-#(""..line))..line)
        win.setBackgroundColor(EditorConf.mainBG)
        win.setTextColor(EditorConf.gutterFG)
        win.write("\x95")
        win.setTextColor(EditorConf.mainFG)
    end
    writeGutter(1)
    for char in data:gmatch(".") do
        local cX, cY = win.getCursorPos()
        if char == "\n" then
            win.setCursorPos(1, cY+1)
            writeGutter(cY+1)
            recolor(bottomBar, colors.orange, colors.black)
            bottomBar.setCursorPos(1, 1)
            bottomBar.write(" Render: "..cY.."/"..lineCount)
        elseif char == "\r" then
            lineEndings = "CRLF"
            win.setCursorPos(1, cY)
        else
            win.write(char)
        end
    end
end

local function floodChars(win, which)
    local w, h = win.getSize()
    for y = 1, h do
        win.setCursorPos(1, y)
        for x = 1, w do
            win.write(which)
        end
    end
end

local function shortNumber(number)
    local strv = ""..number
    if #strv > 6 then
        return math.floor(number/1000000) .. "MB"
    elseif #strv > 3 then
        return math.floor(number/1000) .. "KB"
    else
        return strv
    end
end

BottomBarConf = {
    fileBG = colors.gray,
    fileFG = colors.white,
    mainBG = colors.blue,
    mainFG = colors.white,
    maxFileLen = 15,
}

local fileName
if file == nil then
    fileName = "<new>"
else
    fileName = file:match("([^/]+)$")
end
local fileExtension
if fileName:match("%.") then
    fileName, fileExtension = fileName:match("([^.]*)%.(.-)$")
    fileExtension = "."..fileExtension
else
    fileExtension = ""
end
if #fileName > BottomBarConf.maxFileLen then
    fileName = fileName:sub(1, BottomBarConf.maxFileLen-3) .. ".."
end
fileName = fileName .. fileExtension

local ok, contents

local function drawBottomBar(win)  -- TODO extensibility
    local w, h = win.getSize()
    win.clear()
    win.setBackgroundColor(BottomBarConf.fileBG)
    win.setTextColor(BottomBarConf.fileFG)
    win.setCursorPos(1, 1)
    local leftText = " " .. fileName .. " ".. shortNumber(#contents)
    win.write(leftText)
    win.setTextColor(BottomBarConf.fileBG)
    win.setBackgroundColor(BottomBarConf.mainBG)
    win.write("\x9f")
    win.setTextColor(BottomBarConf.mainFG)
    local rightText = line .. ":" .. col .. " " .. lineEndings .. " "
    win.write((" "):rep(w-#rightText-#leftText-1))
    win.write(rightText)
end

-- Initial file loading process
recolor(term, colors.black, colors.white)
recolor(editWindow, colors.black, colors.gray)
recolor(topBar, colors.gray, colors.white)
recolor(bottomBar, colors.red, colors.white)
bottomBar.write("Loading contents...")
editWindow.setCursorPos(1, 1)
floodChars(editWindow, DRAWING_CHARS.cross)
ok, contents = loadInFile()
recolor(editWindow, colors.black, colors.white)
if not ok then
    recolor(editWindow, colors.black, colors.red)
    recolor(bottomBar, colors.red, colors.white)
    bottomBar.setCursorPos(1, 1)
    bottomBar.write("[Error] " .. contents:sub(1, 30) .. "...")
    editWindow.setCursorPos(1, 1)
    editWindow.write(contents)
    editWindow.setCursorPos(1, 2)
    editWindow.write("Press any key to exit")
    os.pullEvent("key")
    term.clear()
    term.setCursorPos(1, 1)
    return
end
drawInitial(editWindow, contents)
recolor(bottomBar, colors.blue, colors.white)
drawBottomBar(bottomBar)

read()
term.clear()
term.setCursorPos(1, 1)
