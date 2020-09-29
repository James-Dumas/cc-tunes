local screen = {
    w = 51,
    h = 19
}

local speaker = peripheral.find("speaker")
if not speaker then
    error("No speaker connected.")
end

local saveFormatVer = 1

local instruments = {
    "bass",
    "snare",
    "hat",
    "basedrum",
    "bell",
    "flute",
    "chime",
    "guitar",
    "xylophone",
    "iron_xylophone",
    "cow_bell",
    "didgeridoo",
    "bit",
    "banjo",
    "pling",
    "harp",
}

local state = {}

local mChoices = {
    "Load Album",
    "Load Song",
    "Exit"
}
local fMessage

local function init()
    fMessage = "Press Ctrl to access menu"
    state.album = false
    state.playing = false
    state.dirLoc = nil
    state.albumIndex = 1
    state.songFrameIndex = 0
    state.songPerc = 0
    state.running = true
    state.artwork = nil
    state.song = nil
    state.nextSongPath = nil
    state.prevSongPath = nil
    state.rewind = false
    state.skip = false
    state.albumTitle = ""
    state.songTitle = ""
    state.author = ""
end

--[[
    Draws all the interface portions of the program.
]]
local function drawInterface()
    term.setBackgroundColor(colors.black)
    
    --player button
    if state.song ~= nil then
        term.setTextColor(colors.white)
    else
        term.setTextColor(colors.lightGray)
    end

    term.setCursorPos(5, screen.h - 2)

    if state.playing then
        term.write("\143")
    else
        term.write("\16")
    end
    
    --back and forward button
    if state.song ~= nil and state.album then
        term.setTextColor(colors.white)
    else
        term.setTextColor(colors.lightGray)
    end

    term.setCursorPos(2, screen.h - 2)
    term.write("\171")

    term.setCursorPos(8, screen.h - 2)
    term.write("\187")

    term.setTextColor(colors.white)

    --song info
    if state.song ~= nil then
        term.setCursorPos(25, 6)
        term.write(state.songTitle)

        if state.albumTitle == "" or state.albumTitle == nil then
            term.setCursorPos(25, 8)
            term.write(state.author)
        else
            term.setCursorPos(25, 8)
            term.write(state.albumTitle)
            term.setCursorPos(25, 10)
            term.write(state.author)
        end
    end

    -- Footer
    term.setCursorPos(1, screen.h)
    term.setTextColor(colors.yellow)
    term.clearLine()
    term.write(fMessage)
end

local function drawScrubBar()
    local scrubPos = 11 + math.floor((state.songPerc * ((screen.w - 2) - 11)) + 0.5);

    for i = 11, screen.w - 2 do
        if i == scrubPos and state.song ~= nil then
            term.setBackgroundColor(colors.white)
        else 
            term.setBackgroundColor(colors.gray)
        end

        term.setCursorPos(i ,screen.h - 2)
        term.write(" ")
    end
end

--[[
    Converts Hexdecimal to 10 based number color ids
]]
local tColorLookup = {}
for n=1,16 do
    tColorLookup[ string.byte( "0123456789abcdef",n,n ) ] = 2^(n-1)
end
local function getColorOf( char )
    -- Values not in the hex table are transparent (canvas colored)
    return tColorLookup[char]
end

--[[
    loads a nfp file.
]]
local function loadArtwork(path)
    state.artwork = {}
    -- Load the file
    if fs.exists(path) then
        local file = fs.open(path, "r")
        local sLine = file.readLine()
        while sLine do
            local line = {}
            for x=1,screen.w-2 do
                line[x] = getColorOf( string.byte(sLine,x,x) )
            end
            table.insert( state.artwork, line )
            sLine = file.readLine()
        end
        file.close()
    end
end

--[[
    Function to get the color of a pixel from artwork.
]]
local function getCanvasPixel( x, y )
    if state.artwork[y] then
        return state.artwork[y][x]
    end
    return 0
end

--[[
    Function to draw a cropped version of a nfp file.
]]
local function drawArtwork()
    local xOffset = 2
    local yOffset = 1
    
    if state.artwork ~= nil then
        for y=1, 14, 1 do
            for x=1, 20, 1 do
                term.setBackgroundColor(getCanvasPixel(x, y))
                term.setCursorPos(x + xOffset, y + yOffset)
                term.write(" ")
            end
        end
    else 
        term.setBackgroundColor(colors.gray)
        for y=1, 14, 1 do
            for x=1, 20, 1 do
                term.setCursorPos(x + xOffset, y + yOffset)
                term.write(" ")
            end
        end
    end
end

--[[
    wait for an event given multiple different filters
]]
local function pullEventMultiple(...)
    local eventData = {}
    functions = {}
    for i, filter in ipairs({...}) do
        functions[i] = function()
            eventData = {os.pullEvent(filter)}
        end
    end

    parallel.waitForAny(unpack(functions))
    return unpack(eventData)
end

--[[
    Loads a directory as an album.

    @param [string] path
]]
local function loadAlbum(path)
    if fs.exists(path) and fs.isDir(path) then
        state.albumIndex = 1
        state.album = true
        state.albumTitle = path
        state.dirLoc = path
        if fs.exists(path .. "artwork.nfp") and not fs.isDir(path .. "artwork.nfp") then
            loadArtwork(path .. "artwork.nfp")
        end

        local song = nil
        for f in fs.list(path) do
            if not fs.isDir(f) then
                song = {path = f, data = loadSong()}
                if song.data ~= nil then
                    startSong(song)
                    break
                end
            end
        end
    else
        fMessage ="Directory does not exist" 
    end
end

local function loadSong(path, reportError)
    if not fs.exists(path) then
        if reportError then
            -- TODO: do something when the file trying to be loaded does not exist
        end
        return nil
    end
    local infile = io.open(path, "r")
    local lineNum = 1
    local length = 0
    local formatVer = 1
    local song = {}
    for line in infile:lines() do
        if lineNum == 1 then -- format version
            if line:find("brownbricksaudio") ~= 1 then
                if reportError then
                    -- TODO: do something when the file trying to be loaded isn't a valid audio file
                end
                return nil
            end
            local s, e = line:find("format v")
            if s ~= nil then
                formatVer = tonumber(line:sub(e + 1))
                if formatVer > saveFormatVer then
                    if reportError then
                        -- TODO: do something when the file trying to be loaded is a newer version than what can be recognized
                    end
                    return nil
                end
            end
        elseif lineNum == 2 then -- title
            song.title = line
        elseif lineNum == 3 then -- author name
            song.author = line
        else -- song data
            song[length] = {}
            if line:find("-") ~= nil then -- song waits some number of ticks
                local silentTicks = tonumber(line:sub(2))
                length = length + silentTicks
            else -- song has notes
                for i = 1, line:len() / 6 do
                    local s = (i - 1) * 6
                    local inst = instruments[tonumber(line:sub(s + 3, s + 4))]
                    local volume = (tonumber(line:sub(s + 5, s + 6)) + 1) / 16
                    local pitch = tonumber(line:sub(s + 1, s + 2))
                    song[length][i] = {inst, volume, pitch}
                end
                length = length + 1
            end
        end
        lineNum = lineNum + 1
    end
    song.length = length

    return song
end

local function startSong(song)
    state.song = song
    state.author = song.data.author
    state.songTitle = song.data.title
    state.songFrameIndex = 1
    state.songPerc = 0
    state.playing = true
    state.nextSongPath = nil
    state.prevSongPath = nil
    if album then
        -- set next and prev song
        local prev = nil
        local setNext = false
        for f in fs.list(state.dirLoc) do
            if setNext and not fs.isDir(f) and f ~= state.dirLoc .. "artwork.nfp" then
                state.nextSongPath = f
                break
            end
            if f == state.song.path then
                state.prevSongPath = prev
                setNext = true
            end
            prev = f
        end
    end
end

--[[
    A function to request text input from the user
]]
local function getFileName()
    term.setCursorPos(1, screen.h)
    term.clearLine()
    term.write(">")
    return read()
end

--[[
    This function opens the user menu and handles the user clicking on menu options.
]]
local function accessMenu()
    -- Selected menu option
    local selection = 1
    
    term.setBackgroundColor(colors.black)

    while true do
        -- Draw the menu
        term.setCursorPos(1,screen.h)
        term.clearLine()
        term.setTextColor(colors.white)
        for k,v in pairs(mChoices) do
            if selection==k then 
                term.setTextColor(colors.yellow)
                local ox,_ = term.getCursorPos()
                term.write("["..string.rep(" ",#v).."]")
                term.setCursorPos(ox+1,screen.h)
                term.setTextColor(colors.white)
                term.write(v)
                term.setCursorPos(term.getCursorPos()+1,screen.h)
            else
                term.write(" "..v.." ")
            end
        end
        
        -- Handle input in the menu
        local event, key = os.pullEvent("key")
        -- S and E are shortcuts
        if key == keys.s then
            selection = 1
            key = keys.enter
        elseif key == keys.e then
            selection = 2
            key = keys.enter
        end
    
        if key == keys.right then
            -- Move right
            selection = selection + 1
            if selection > #mChoices then
                selection = 1
            end
            
        elseif key == keys.left and selection > 1 then
            -- Move left
            selection = selection - 1
            if selection < 1 then
                selection = #mChoices
            end
            
        elseif key == keys.enter then
            -- Select an option
            if mChoices[selection]=="Load Album" then 
                local fileLoc = getFileName()
                loadAlbum(fileLoc)
            elseif mChoices[selection]=="Exit" then 
                state.running = false
            elseif mChoices[selection]=="Load Song" then
                local fileLoc = getFileName()
                local song = {path = fileLoc, data = loadSong(fileLoc, true)}
                if song.data ~= nil then
                    startSong(song)
                end
            end
            -- Cancel the menu
            break
        elseif key == keys.leftCtrl or keys == keys.rightCtrl then
            -- Cancel the menu
            break
        end
    end
end

-- This thread is for handling user input to the program.
local function mainThread()
    while state.running do
        --render screen
        term.setBackgroundColor(colors.black)
        term.clear()
        drawInterface()
        drawScrubBar()
        drawArtwork()

        --wait for event
        local event, p1, p2, p3 = pullEventMultiple("key", "mouse_click", "timer")

        --if key event
        if event == "key" then

            --ctrl: open menu
            if p1==keys.leftCtrl or p1==keys.rightCtrl then
                accessMenu()
            end
        elseif event == "mouse_click" then

            --if left mouse click
            if p1 == 1 then

                --if is loaded and clicked on point (5, screen.h -2) then invert playing state
                if state.song ~= nil and p2 == 5 and p3 == (screen.h - 2) then
                    state.playing = not state.playing
                end

                --if prevSongPath is set and clicked on point (2, screen.h - 2) then set the state to rewind
                if state.prevSongPath ~= nil and p2 == 2 and p3 == (screen.h - 2) then
                    state.rewind = true
                end

                --if nextSongPath is set and clicked on point (8, screen.h - 2) then set the state to skip
                if state.nextSongPath ~= nil and p2 == 8 and p3 == (screen.h - 2) then
                    state.skip = true
                end
            end
        end
    end
end

local function songThread()
    time = os.time()
    alarmTime = (time + 0.001) % 24
    os.setAlarm(alarmTime)
    while state.running do
        os.pullEvent("alarm")
        time = os.time()
        alarmTime = (time + 0.001) % 24
        os.setAlarm(alarmTime)

        if state.playing then
            state.songPerc = state.songFrameIndex / state.song.data.length
            for i, note in ipairs(state.song.data[state.songFrameIndex] or {}) do
                speaker.playNote(unpack(note))
            end
            state.songFrameIndex = state.songFrameIndex + 1
            drawScrubBar()
        end

        if state.rewind then
            state.rewind = false
            if state.prevSongPath ~= nil and state.songFrameIndex < 40 then
                local song = {path = state.prevSongPath, data = loadSong(state.prevSongPath)}
                if song.data ~= nil then
                    startSong(song)
                end
            else
                state.songFrameIndex = 0
            end
            os.startTimer(0)
        end

        if state.skip then
            state.skip = false
            if state.nextSongPath ~= nil then
                local song = {path = state.nextSongPath, data = loadSong(state.nextSongPath)}
                if song.data ~= nil then
                    startSong(song)
                end
            else
                state.song = nil
                state.playing = false
            end
            os.startTimer(0)
        end

        if state.song ~= nil and state.songFrameIndex >= state.song.data.length then
            if state.nextSongPath ~= nil then
                local song = {path = state.nextSongPath, data = loadSong(state.nextSongPath)}
                if song.data ~= nil then
                    startSong(song)
                end
            else
                state.song = nil
                state.playing = false
            end
            os.startTimer(0)
        end
    end
end

init()
parallel.waitForAny(mainThread, songThread)
term.setCursorPos(1, 1)
term.clear()
