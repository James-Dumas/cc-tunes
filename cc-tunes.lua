local screen = {
    w = 51,
    h = 19
}

local state = {}

local mChoices = {
    "Load Album",
    "Load Song",
    "Exit"
}
local fMessage

local function init()
    term.clear()
    fMessage = "Press Ctrl to access menu"
    state.loaded = false
    state.album = false
    state.playing = false
    state.dirLoc = nil
    state.albumIndex = 1
    state.songPerc = 0
    state.running = true
    state.artwork = nil
    state.song = nil
    state.albumTitle = ""
    state.songTitle = ""
    state.author = ""
end

local function drawInterface()
    term.setBackgroundColor(colors.black)
    
    --player button
    if state.loaded then
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
    if state.loaded and state.album then
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


    -- Footer
    term.setCursorPos(1, screen.h)
    term.setTextColor(colors.yellow)
    term.clearLine()
    term.write(fMessage)

    --song scrub bar
    local scrubPos = 11 + math.floor(state.songPerc * ((screen.w - 3) - 11));

    for i=11, screen.w - 2, 1 do
        if i == scrubPos and state.loaded then
            term.setBackgroundColor(colors.white)
        else 
            term.setBackgroundColor(colors.gray)
        end

        term.setCursorPos(i ,screen.h - 2)
        term.write(" ")
    end
end

local tColorLookup = {}
for n=1,16 do
    tColorLookup[ string.byte( "0123456789abcdef",n,n ) ] = 2^(n-1)
end
local function getColorOf( char )
    -- Values not in the hex table are transparent (canvas colored)
    return tColorLookup[char]
end

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

local function getCanvasPixel( x, y )
    if state.artwork[y] then
        return state.artwork[y][x]
    end
    return 0
end

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

local function loadAlbum(path)
    if fs.exists(path) and fs.isDir(path) then
        state.albumIndex = 1
        state.album = true
        state.albumTitle = path
        state.dirLoc = path
        if fs.exists(path .. "artwork.nfp") and not fs.isDir(path .. "artwork.nfp") then
            loadArtwork(path .. "artwork.nfp")
        end

        --TODO: Load first song

        state.loaded = true
    else
        fMessage ="Directory does not exist" 
    end
end

--TODO: Make a file format and then make a way to load it
local function loadSong(path)

end

local function getFileName()
    term.setCursorPos(1, screen.h)
    term.clearLine()
    term.write(">")
    return read()
end

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
        local id,key = os.pullEvent("key_up")
        if id == "key" then
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
                    return false
                elseif mChoices[selection]=="Exit" then 
                    return true
                elseif mChoices[selection]=="Load Song" then
                    local fileLoc = getFileName()
                    loadSong(fileLoc)
                end
            elseif key == keys.leftCtrl or keys == keys.rightCtrl then
                -- Cancel the menu
                return false 
            end
        end
    end
end


local function mainThread()
    while state.running do
        drawInterface()
        drawArtwork()

        local event, p1, p2, p3 = os.pullEvent()

        if event == "key_up" then
            if p1==keys.leftCtrl or p1==keys.rightCtrl then
                if accessMenu() then
                    term.setCursorPos(1, 1)
                    term.clear()
                    return
                end

                drawInterface()
            end
        elseif event == "mouse_click" then
            if p1 == 1 then

                if state.loaded and p2 == 5 and p3 == (screen.h - 2) then
                    state.playing = not state.playing
                end
            end
        end

        term.setBackgroundColor(colors.black)
        term.clear()
    end
end

local function songThread()
    while state.running do
        sleep(1)
    end
end

init()
parallel.waitForAny(mainThread, songThread)
