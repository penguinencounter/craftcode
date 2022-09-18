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
        file = "<new>"
        return true, ""
    end
    local f = fs.open(cwd .. file, "r")
    if f == nil then
        if fs.isDir(cwd .. file) then
            return false, file.." is a directory"
        end
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

local sLine = 1
local sCol = 1

local tW, tH = term.getSize()
local editWindow = window.create(term.current(), 1, 2, tW, tH-2)
local topBar = window.create(term.current(), 1, 1, tW, 1)
local bottomBar = window.create(term.current(), 1, tH, tW, 1)

EditorConf = {
    gutterBG = colors.black,
    gutterMarkerBG = colors.black,
    gutterMarkerSize = 0,
    mainBG = colors.black,
    mainFG = colors.white,
}

GutterDefaults = {
    color = colors.gray,
    marker = "",
    priority = -99999999,
    mode = "append"
}
NoDefaultMarkers = {
    marker = "",
    mode = "replace",
    priority = -99999998
}
SelectedLine = {
    priority = 0,
    color = colors.lightGray,
    selectedLine = true
}

GutterOverrides = {
    --[[ EXAMPLE:
    [1] = {
        NoDefaultMarkers,
        {
            color = colors.blue,
            marker = "\x18",
            priority = 1,
            mode = "append"
        },
        {
            color = colors.blue,
            marker = "\x19",
            priority = 1,
            mode = "append"
        },
        {
            color = colors.red,
            marker = "\x07",
            priority = 5,
            mode = "append"
        },
        {
            color = colors.green,
            marker = "\x10",
            priority = 0,
            mode = "append"
        },
        {
            marker = "\x1f",
            priority = -1,
            mode = "append"
        }
    }
    ]]--
}

function table.clone(org)
    return {table.unpack(org)}
end
function table.merge(one, two)
    local result = {}
    for _, v in ipairs(one) do
        table.insert(result, v)
    end
    for _, v in ipairs(two) do
        table.insert(result, v)
    end
    return result
end

local scrollX, scrollY = 0, 0
local totalLineCount = 0
local lines = {}

local function writeGutter(win, line)
    win.setBackgroundColor(EditorConf.gutterBG)

    -- sort out gutter data
    local gutterDatas = table.merge(table.clone(GutterOverrides[line] or {}), {GutterDefaults})
    table.sort(gutterDatas, function(a, b) return a.priority < b.priority end)

    local gutterData = {}
    local markers = {}
    local totalMarkerLen = 0
    for _, gD in ipairs(gutterDatas) do
        local mode = gD.mode or GutterDefaults.mode
        local color = gD.color or GutterDefaults.color
        for k, v in pairs(gD) do
            if k == "color" then
                gutterData.color = v
            elseif k == "marker" then
                if mode == "append" then
                    table.insert(markers, {text=v, color=color})
                    totalMarkerLen = totalMarkerLen + #v
                elseif mode == "replace" then
                    markers = {{text=v, color=color}}
                    totalMarkerLen = #v
                end
            end
        end
    end
    local counter = 0
    local function addCounts(a) counter = counter + #a end

    local spacing = (" "):rep(EditorConf.gutterMarkerSize-totalMarkerLen)
    win.setBackgroundColor(EditorConf.gutterMarkerBG)
    win.write(spacing)
    addCounts(spacing)
    for _, m in ipairs(markers) do
        win.setTextColor(m.color)
        win.write(m.text)
        addCounts(m.text)
    end
    win.setBackgroundColor(EditorConf.gutterBG)
    win.setTextColor(gutterData.color)
    win.write(" ")
    addCounts(" ")
    local a = (" "):rep(#(""..totalLineCount)-#(""..line))..line
    win.write(a)
    addCounts(a)
    win.setBackgroundColor(EditorConf.mainBG)
    win.setTextColor(gutterData.color)
    win.write("\x95")
    addCounts("\x95")
    win.setTextColor(EditorConf.mainFG)
    return counter
end

local gutterWidth = 0
local function renderContent(win)
    recolor(win, EditorConf.mainBG, EditorConf.mainFG)
    local w, h = win.getSize()
    local low, high = scrollY+1, scrollY+h
    for i=low,high do
        if i > totalLineCount then break end
        win.setCursorPos(1, i-low+1)
        gutterWidth = writeGutter(win, i)
        win.write(lines[i]:sub(scrollX+1, scrollX+w-gutterWidth))
    end
    return sCol-scrollX+gutterWidth, sLine-scrollY
end

local function updateCursorPos(viewport, newLine, newCol)
    GutterOverrides[sLine] = GutterOverrides[sLine] or {}
    local vX, vY = viewport.getSize()
    local toDelete = nil
    for i, override in ipairs(GutterOverrides[sLine]) do
        if override.selectedLine then
            toDelete = i
        end
    end
    if toDelete then
        table.remove(GutterOverrides[sLine], toDelete)
    end
    sLine = newLine
    sCol = newCol
    if sLine < 1 then sLine = 1 end
    if sLine > totalLineCount then sLine = totalLineCount end
    if sCol < 1 then sCol = 1 end
    if sLine >= scrollY + vY then
        scrollY = sLine - vY + 1
    elseif sLine <= scrollY then
        scrollY = sLine - 1
    end
    if sCol >= scrollX + vX - gutterWidth then
        scrollX = sCol - vX + gutterWidth
    elseif sCol <= scrollX then
        scrollX = sCol - 1
    end
    if scrollX < 0 then scrollX = 0 end
    if scrollY < 0 then scrollY = 0 end
    GutterOverrides[sLine] = GutterOverrides[sLine] or {}
    table.insert(GutterOverrides[sLine], SelectedLine)
end

local function metadata(win, data)
    recolor(win, EditorConf.mainBG, EditorConf.mainFG)
    totalLineCount = 0
    lines = {}
    for line in data:gmatch("(.-)\n") do
        totalLineCount = totalLineCount + 1
        table.insert(lines, line)
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
        return strv .. "B"
    end
end

BottomBarConf = {
    fileBG = colors.gray,
    fileFG = colors.white,
    mainBG = colors.blue,
    mainFG = colors.white,
    maxFileLen = 10,
    maxLeftSideLen = 30,
    readOnlyBG = colors.orange,
    readOnlyFG = colors.black,
    readOnlyText = " ro"
}

local fileName
if file == nil then
    fileName = "<new>"
else
    fileName = file:match("([^/]+)$")
end
local isReadOnly = fs.isReadOnly(file)
if isReadOnly == nil then isReadOnly = fs.isReadOnly(cwd) end
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
    local function leftSide(disableFileName, disableSize)
        disableFileName = disableFileName or false
        disableSize = disableSize or false

        local totalWidth = 0

        win.setBackgroundColor(BottomBarConf.fileBG)
        win.setTextColor(BottomBarConf.fileFG)
        win.setCursorPos(1, 1)
        local leftText = ""
        if not disableFileName then
            leftText = leftText .. " " .. fileName
        end
        if not disableSize then
            leftText = leftText .. " (" .. shortNumber(#contents) .. ")"
        end
        if isReadOnly then
            totalWidth = totalWidth + #BottomBarConf.readOnlyText + 1 -- divider
        end
        totalWidth = totalWidth + #leftText
        if totalWidth > BottomBarConf.maxLeftSideLen and not (disableFileName and disableSize) then
            if not (disableSize or disableFileName) then
                return leftSide(false, true)
            elseif not disableFileName and disableSize then
                return leftSide(true, false)
            else
                return leftSide(true, true)
            end
        else
            win.write(leftText)
            win.setTextColor(BottomBarConf.fileBG)
            win.setBackgroundColor(isReadOnly and BottomBarConf.readOnlyBG or BottomBarConf.mainBG)
            win.write("\x9f")
            if isReadOnly then
                win.setTextColor(BottomBarConf.readOnlyFG)
                win.write(BottomBarConf.readOnlyText)
                win.setTextColor(BottomBarConf.readOnlyBG)
                win.setBackgroundColor(BottomBarConf.mainBG)
                win.write("\x9f")
            end
        end
        return totalWidth
    end
    local leftWidth = leftSide()
    win.setTextColor(BottomBarConf.mainFG)
    local rightText = scrollX .. "\x10 " .. scrollY .. "\x1f " .. sLine .. ":" .. sCol .. " " .. lineEndings .. " "
    win.write((" "):rep(w-#rightText-leftWidth-1))
    win.write(rightText)
end

-- Initial file loading process
local function startup()
    term.setCursorBlink(true)
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
        return true
    end
    metadata(editWindow, contents)
    recolor(bottomBar, colors.blue, colors.white)
    drawBottomBar(bottomBar)
    updateCursorPos(editWindow, 1, 1)
    renderContent(editWindow)
    return false
end

local function cleanExit()
    term.clear()
    term.setCursorPos(1, 1)
end

-- main loop for editing
local function editTick()
    local event = {os.pullEvent()}
    if event[1] == "key" then
        local _, key, held = unpack(event)
        if key == keys.right then
            updateCursorPos(editWindow, sLine, sCol + 1)
        elseif key == keys.left then
            updateCursorPos(editWindow, sLine, sCol - 1)
        elseif key == keys.up then
            updateCursorPos(editWindow, sLine - 1, sCol)
        elseif key == keys.down then
            updateCursorPos(editWindow, sLine + 1, sCol)
        elseif key == keys.home then
            updateCursorPos(editWindow, sLine, 1)
        elseif key == keys["end"] then
            updateCursorPos(editWindow, sLine, #lines[sLine] + 1)
        end
    end
    local cX, cY = renderContent(editWindow)
    recolor(bottomBar, colors.blue, colors.white)
    drawBottomBar(bottomBar)
    editWindow.setCursorPos(cX, cY)
end

if startup() then return end
while true do
    editTick()
end
cleanExit()
