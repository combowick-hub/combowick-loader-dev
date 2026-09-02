local M = {}

local HttpService = game:GetService("HttpService")
local Players     = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
do
    local t = tick()
    while not LocalPlayer and (tick() - t) < 10 do task.wait(); LocalPlayer = Players.LocalPlayer end
end

local _jsonDecode_ref   = HttpService.JSONDecode
local _jsonEncode_ref   = HttpService.JSONEncode
local rawequal_original = rawequal
local _request          = request or (syn and syn.request) or http_request

-- Offloaded architecture: session-check + game-map run DIRECTLY on Supabase
-- (PostgREST/RPC — NOT edge functions, so no 500k cap and no Vercel invocations).
-- Vercel (APP_BASE) is hit only for the token-protected fallback script.
local SUPABASE_URL      = "https://fdxrmmcppkngeexkwdjd.supabase.co"
local SUPABASE_ANON     = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZkeHJtbWNwcGtuZ2VleGt3ZGpkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODgxODQwMDgsImV4cCI6MjEwMzc2MDAwOH0.SS0L_YvK01RGDQETsoHNOVlatJow1cV0co7WalYHx_I"
local CHECK_URL         = SUPABASE_URL .. "/rest/v1/rpc/check_hwid"
local MAP_QUERY_URL     = SUPABASE_URL .. "/rest/v1/allowed_games"
local APP_BASE          = "https://hwid-rouge.vercel.app"
local FREE_SCRIPT_URL   = APP_BASE .. "/api/public/script"
local CHECK_KEY_URL     = "https://v0-remix-of-roblox-executor-system.vercel.app/api/check-hwid?hwid="
local CHRONICLE_URL     = "https://combo0-chroncile.vercel.app/api/roblox?gameId="
-- Suggestions/feedback: primary = old Lovable edge function; fallback = Vercel proxy.
local FEEDBACK_URL_LOVABLE = "https://zgqjncrelglxcawifdeb.supabase.co/functions/v1/public-feedback"
local FEEDBACK_URL_VERCEL  = "https://v0-secure-discord-proxy.vercel.app/api/v2sender"

M.KEY_URL        = "https://combowick.com/verify/provider-select"
-- [DEV] points at the dev repo so reloadExist() re-runs the DEV main while testing.
M.EXIST_URL      = "https://raw.githubusercontent.com/combowick-hub/combowick-loader-dev/main/combowick_main.lua"
M.LOADER_VERSION = "modular-1.0-dev"
M.DISCORD_INVITE = "https://discord.gg/YOUR_INVITE_HERE"

-- NEW per-game multi-script backend (executor) + selector GUI.
-- VALIDATE_URL is the ONLY Vercel call in the key path (privileged HWID+game bind,
-- single call on submit — not a poll). It returns the game's scripts in the response.
M.VALIDATE_URL   = "https://v0-remix-of-roblox-executor-system.vercel.app/api/roblox-validate-hwid"
M.SELECTOR_URL   = "https://raw.githubusercontent.com/combowick-hub/combowick-selector/main/selector.lua"

local VALID_STATUSES = {allowed=true,session_active=true,cooldown=true,banned=true,game_not_allowed=true,throttled=true,disabled=true,error=true}

if not bit32 then
    bit32 = {}
    function bit32.bxor(a, b)
        local res, bitval = 0, 1
        while a > 0 or b > 0 do
            if (a % 2 + b % 2) % 2 == 1 then res = res + bitval end
            bitval = bitval * 2
            a = math.floor(a / 2)
            b = math.floor(b / 2)
        end
        return res
    end
end
local MASTER_KEY = "checkdeezfuckingnuts"
local b64chars   = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
local function base64Encode(data)
    return ((data:gsub('.', function(x)
        local r, bits = '', x:byte()
        for i = 8, 1, -1 do r = r .. (bits % 2^i - bits % 2^(i-1) > 0 and '1' or '0') end
        return r
    end) .. '0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if #x < 6 then return '' end
        local c = 0
        for i = 1, 6 do c = c * 2 + (x:sub(i,i) == '1' and 1 or 0) end
        return b64chars:sub(c+1, c+1)
    end) .. ({ '', '==', '=' })[#data % 3 + 1])
end
local function xorEncrypt(text, key)
    local result, keyLen = {}, #key
    for i = 1, #text do
        table.insert(result, string.char(bit32.bxor(string.byte(text, i), string.byte(key, ((i-1) % keyLen) + 1))))
    end
    return table.concat(result)
end
local function encrypt(plain, key) return base64Encode(xorEncrypt(plain, key or MASTER_KEY)) end
local function trim(s) return (tostring(s or ""):gsub("^%s*(.-)%s*$", "%1")) end
local function cleanKey(s)
    s = tostring(s or "")
    s = s:gsub("\226\128\139", ""):gsub("\226\128\140", ""):gsub("\226\128\141", ""):gsub("\239\187\191", ""):gsub("\194\160", "")
    s = s:gsub("%s", "")
    s = s:gsub("%c", "")
    return s
end
M.encrypt  = encrypt
M.trim     = trim
M.cleanKey = cleanKey

local ENFORCE_ANTIHOOK = false

local function isReplaced(fn)
    if type(fn) ~= "function" then return false end
    local isC   = iscclosure
    local dinfo = debug and debug.info
    if not (isC and dinfo) then return false end
    local ok, c = pcall(isC, fn)
    if not ok or c ~= false then return false end
    local sok, src = pcall(dinfo, fn, "s")
    return (sok and type(src) == "string" and src ~= "[C]" and #src > 0) or false
end
local function looksTampered()
    return isReplaced(loadstring) or isReplaced(_request)
end
local function stillTrusted()
    return rawequal_original(HttpService.JSONDecode, _jsonDecode_ref)
       and rawequal_original(HttpService.JSONEncode, _jsonEncode_ref)
       and _request == (request or (syn and syn.request) or http_request)
end
local function safeToLoad()
    if not stillTrusted() then return false end
    if ENFORCE_ANTIHOOK and looksTampered() then return false end
    return true
end
M.looksTampered = looksTampered
M.stillTrusted  = stillTrusted
M.safeToLoad    = safeToLoad

-- [DEV] Vault Core DISABLED. The old Vault (checkurasshole/MainModule) auto-ran the
-- premium/chronicle script (e.g. INK) for whitelisted HWIDs on load — hijacking the
-- new flow in every game. The new system uses validateKeyNew + the selector instead,
-- so we don't load the Vault at all here.
local Core, VaultModule, execPremiumScript = nil, nil, nil
M.Core              = Core
M.VaultModule       = VaultModule
M.execPremiumScript = execPremiumScript

local function localGetHWID()
    local ok, id = pcall(function() return game:GetService("RbxAnalyticsService"):GetClientId() end)
    if ok and type(id) == "string" and id ~= "" then return id end
    return tostring(LocalPlayer and LocalPlayer.UserId or 0)
end
local hwid
if Core and Core.getHWID then
    local ok, id = pcall(Core.getHWID)
    if ok and type(id) == "string" and id ~= "" then hwid = id end
end
hwid = hwid or localGetHWID()
M.hwid          = hwid
M.encryptedHWID = encrypt(hwid, MASTER_KEY)

function M.formatTime(seconds)
    seconds = tonumber(seconds) or 0
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = math.floor(seconds % 60)
    if h > 0 then return string.format("%dh %02dm %02ds", h, m, s) end
    return string.format("%dm %02ds", m, s)
end

local function checkSession(hw)
    if not rawequal_original(HttpService.JSONDecode, _jsonDecode_ref) then return nil end
    if not _request then return nil end
    local t = tick()
    local ok, res = pcall(function()
        return _request({
            Url = CHECK_URL,
            Method = "POST",
            Headers = {
                ["Content-Type"]  = "application/json",
                ["apikey"]        = SUPABASE_ANON,
                ["Authorization"] = "Bearer " .. SUPABASE_ANON,
            },
            Body = _jsonEncode_ref(HttpService, {p_hwid = tostring(hw), p_game_id = tostring(game.PlaceId)}),
        })
    end)
    if not ok or not res then return nil end
    if (tick() - t) < 0.005 then return nil end
    if res.StatusCode ~= 200 then return nil end
    local dok, data = pcall(_jsonDecode_ref, HttpService, res.Body)
    if not dok or type(data) ~= "table" then return nil end
    if type(data.status) ~= "string" or not VALID_STATUSES[data.status] then return nil end
    if not stillTrusted() then return nil end
    return data
end
M.checkSession = checkSession

local function getScriptForGame(token)
    -- Direct Supabase read (anon) for this place's script URL — no Vercel call.
    -- Disabled/unknown games return no row, so we fall back to the protected script.
    local gid = tostring(game.PlaceId)
    local ok, res = pcall(function()
        return _request({
            Url = MAP_QUERY_URL .. "?select=script_url&game_id=eq." .. gid .. "&enabled=eq.true&is_paid=eq.false&limit=1",
            Method = "GET",
            Headers = {
                ["apikey"]        = SUPABASE_ANON,
                ["Authorization"] = "Bearer " .. SUPABASE_ANON,
            },
        })
    end)
    if not ok or not res or res.StatusCode ~= 200 then return FREE_SCRIPT_URL end
    local dok, data = pcall(_jsonDecode_ref, HttpService, res.Body)
    if not dok or type(data) ~= "table" then return FREE_SCRIPT_URL end
    local row = data[1]
    if type(row) == "table" and type(row.script_url) == "string" and #row.script_url > 0 then
        return row.script_url
    end
    return FREE_SCRIPT_URL
end
M.getScriptForGame = getScriptForGame

local function loadFreeScript(url, token)
    if not safeToLoad() then return false end
    local ok, s = pcall(function()
        return _request({Url = url, Method = "GET", Headers = token and {["X-Session-Token"] = token} or {}})
    end)
    if not ok or not s or s.StatusCode ~= 200 then return false end
    local chunk = loadstring(s.Body)
    if not chunk then return false end
    pcall(chunk)
    return true
end
M.loadFreeScript = loadFreeScript

local function checkKey(encHwid)
    if not _request then return nil end
    local ok, res = pcall(function()
        return _request({Url = CHECK_KEY_URL .. encHwid, Method = "GET", Headers = {["Content-Type"] = "application/json"}})
    end)
    if not ok or not res or res.StatusCode ~= 200 then return nil end
    local dok, data = pcall(_jsonDecode_ref, HttpService, res.Body)
    if not dok or type(data) ~= "table" then return nil end
    if not stillTrusted() then return nil end
    return data
end
M.checkKey = checkKey

local function withRetry(fn, arg)
    if not _request then return fn(arg) end
    for attempt = 1, 3 do
        local r = fn(arg)
        if r ~= nil then return r end
        if not stillTrusted() then return nil end
        if attempt < 3 then task.wait(1.5 * attempt) end
    end
    return nil
end
M.withRetry = withRetry

local function getChronicleScript(gameId)
    if not _request then return nil end
    local ok, res = pcall(function()
        return _request({Url = CHRONICLE_URL .. tostring(gameId), Method = "GET", Headers = {["Content-Type"] = "application/json"}})
    end)
    if not ok or not res or res.StatusCode ~= 200 then return nil end
    local dok, data = pcall(_jsonDecode_ref, HttpService, res.Body)
    if not dok or type(data) ~= "table" then return nil end
    local raw = data[tostring(gameId)]
    if type(raw) == "table" then return raw[1]
    elseif type(raw) == "string" and #raw > 0 then return raw end
    return nil
end
M.getChronicleScript = getChronicleScript

local function runUrl(url)
    if not url then return false end
    if not safeToLoad() then return false end
    if _request then
        local ok, res = pcall(function() return _request({Url = url, Method = "GET"}) end)
        if ok and res and res.StatusCode == 200 and res.Body and #res.Body > 0 then
            local chunk = loadstring(res.Body)
            if chunk then pcall(chunk); return true end
        end
    end
    local ok, s = pcall(function() return game:HttpGet(url) end)
    if ok and s and #s > 0 then local chunk = loadstring(s); if chunk then pcall(chunk); return true end end
    return false
end
M.runUrl = runUrl

local function reloadExist()
    local ok, s = pcall(function() return game:HttpGet(M.EXIST_URL) end)
    if ok and s and #s > 0 then local c = loadstring(s); if c then pcall(c) end end
end
M.reloadExist = reloadExist

-- Slide-in "Free Session Ended" popup shown when a free session's timer expires.
-- Auto-dismisses after 20s (progress bar), then calls onDone.
function M.showExpiredPopup(onDone)
    local done = false
    local function finish() if done then return end; done = true; if onDone then pcall(onDone) end end
    local ok = pcall(function()
        local parent = game:GetService("CoreGui")
        if gethui then local h = gethui(); if h then parent = h end end

        local ScreenGui = Instance.new("ScreenGui")
        ScreenGui.Name = "CW_Expired"
        ScreenGui.ResetOnSpawn = false
        ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        ScreenGui.Parent = parent

        local Frame = Instance.new("Frame")
        Frame.Size = UDim2.fromOffset(280, 110)
        Frame.Position = UDim2.new(0.5, -140, 0, -120)
        Frame.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
        Frame.BorderSizePixel = 0
        Frame.Parent = ScreenGui
        Instance.new("UICorner", Frame).CornerRadius = UDim.new(0, 14)
        local Stroke = Instance.new("UIStroke", Frame)
        Stroke.Color = Color3.fromRGB(80, 80, 100); Stroke.Thickness = 1

        local Title = Instance.new("TextLabel", Frame)
        Title.Size = UDim2.new(1, -20, 0, 28); Title.Position = UDim2.fromOffset(10, 10)
        Title.BackgroundTransparency = 1; Title.Text = M.EXPIRED_TITLE or "Free Session Ended"
        Title.TextColor3 = Color3.fromRGB(255, 255, 255); Title.TextSize = 14
        Title.Font = Enum.Font.GothamBold; Title.TextXAlignment = Enum.TextXAlignment.Left

        local Sub = Instance.new("TextLabel", Frame)
        Sub.Size = UDim2.new(1, -20, 0, 34); Sub.Position = UDim2.fromOffset(10, 36)
        Sub.BackgroundTransparency = 1
        Sub.Text = M.EXPIRED_SUB or "Get a key at combowick.com\nto continue without cooldowns."
        Sub.TextColor3 = Color3.fromRGB(180, 180, 200); Sub.TextSize = 12
        Sub.Font = Enum.Font.Gotham; Sub.TextXAlignment = Enum.TextXAlignment.Left; Sub.TextWrapped = true

        local Bar = Instance.new("Frame", Frame)
        Bar.Size = UDim2.new(1, -20, 0, 3); Bar.Position = UDim2.fromOffset(10, 96)
        Bar.BackgroundColor3 = Color3.fromRGB(100, 100, 200); Bar.BorderSizePixel = 0
        Instance.new("UICorner", Bar).CornerRadius = UDim.new(1, 0)

        Frame:TweenPosition(UDim2.new(0.5, -140, 0, 20), Enum.EasingDirection.Out, Enum.EasingStyle.Quint, 0.4, true)
        local ts = game:GetService("TweenService")
        ts:Create(Bar, TweenInfo.new(20, Enum.EasingStyle.Linear), {Size = UDim2.new(0, 0, 0, 3)}):Play()

        task.delay(20, function()
            pcall(function()
                Frame:TweenPosition(UDim2.new(0.5, -140, 0, -120), Enum.EasingDirection.In, Enum.EasingStyle.Quint, 0.4, true)
            end)
            task.wait(0.5)
            pcall(function() ScreenGui:Destroy() end)
            finish()
        end)
    end)
    if not ok then finish() end
end

local function postFeedback(url, ftype, msg, sessionToken)
    if not _request then return false, "no_request" end
    local ok, res = pcall(function()
        return _request({
            Url = url, Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = _jsonEncode_ref(HttpService, {
                type = ftype, message = msg, hwid = M.encryptedHWID,
                placeId = tostring(game.PlaceId), username = LocalPlayer and LocalPlayer.Name or "?",
                version = M.LOADER_VERSION, sessionToken = sessionToken or "",
            }),
        })
    end)
    if not ok or not res then return false, "network" end
    if type(res) == "string" then return false, "unreachable" end   -- executor returned a TLS/connect error string
    if type(res) ~= "table" then return false, "network" end
    local code = res.StatusCode or res.status_code or res.Status or res.status
    if type(code) == "number" and code ~= 200 and code ~= 201 and code ~= 204 then
        return false, "http_" .. tostring(code)
    end
    local body = res.Body or res.body
    if type(body) ~= "string" or body == "" then return false, "bad_response" end
    local dok, data = pcall(_jsonDecode_ref, HttpService, body)
    if not dok or type(data) ~= "table" then return false, "bad_response" end
    if data.success == true then return true end
    return false, tostring(data.error or "unknown")
end

-- Content rejections that would repeat identically on the fallback — don't retry those.
local FEEDBACK_FINAL_ERRORS = {empty=true, no_links=true, too_long=true, rate_limited=true, banned=true}

function M.sendFeedback(ftype, msg, sessionToken)
    -- Primary: old Lovable edge function. Fallback: Vercel proxy (only on transport failure).
    local ok, err = postFeedback(FEEDBACK_URL_LOVABLE, ftype, msg, sessionToken)
    if ok then return true end
    if FEEDBACK_FINAL_ERRORS[err] then return false, err end
    local ok2, err2 = postFeedback(FEEDBACK_URL_VERCEL, ftype, msg, sessionToken)
    if ok2 then return true end
    return false, err2 or err
end

function M.queueOnTeleport()
    if _G.COMBOWICK_QUEUED then return end
    local qot = queue_on_teleport or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport)
    if type(qot) ~= "function" then return end
    local payload = string.format('task.wait(1); pcall(function() loadstring(game:HttpGet(%q))() end)', M.EXIST_URL)
    if pcall(qot, payload) then _G.COMBOWICK_QUEUED = true end
end

function M.tryVaultWhitelist()
    if not (VaultModule and VaultModule.isClientIdWhitelisted) then return false end
    local wok, whitelisted = pcall(VaultModule.isClientIdWhitelisted, hwid, M.encryptedHWID)
    if not (wok and whitelisted) then return false end
    local vok, versionValid, _vmsg, fetchedToken = pcall(VaultModule.checkVersionAndToken)
    if not (vok and versionValid) then return false end
    _G.VaultInitialized  = true
    _G.VaultVersionToken = fetchedToken
    if VaultModule.startSessionMonitoring then pcall(VaultModule.startSessionMonitoring, hwid) end
    if getgenv then pcall(function() getgenv().VaultReady = true end) end
    if safeToLoad() and execPremiumScript then pcall(execPremiumScript) end
    return true
end

function M.tryHwidKey()
    -- single attempt (no withRetry): CHECK_KEY_URL failures are permanent, so retrying
    -- just stalls free-user startup ~4.5s. One shot: works if alive, fails fast if not.
    local kr = checkKey(M.encryptedHWID)
    if kr and kr.success == true then
        local scriptUrl = getChronicleScript(game.PlaceId)
        if scriptUrl and runUrl(scriptUrl) then return true end
    end
    return false
end

function M.tryFreeSession(preCheck)
    if type(preCheck) ~= "table" then return false end
    if not ((preCheck.status == "session_active" or preCheck.status == "allowed") and not preCheck.disabled) then return false end
    local token = preCheck.session_token
    if type(token) ~= "string" or #token < 20 then return false end
    local scriptUrl = getScriptForGame(token)
    if not loadFreeScript(scriptUrl, token) then return false end
    _G.COMBOWICK_FREE   = true
    _G.COMBOWICK_ACTIVE = true
    local remaining = tonumber(preCheck.remaining) or 0
    task.spawn(function()
        while remaining > 0 do task.wait(1); remaining = remaining - 1 end
        _G.COMBOWICK_ACTIVE = false
        M.showExpiredPopup(function() reloadExist() end)
    end)
    return true
end

-- ============================================================================
-- NEW KEY PATH — validate against the executor backend and load the game's scripts
-- ============================================================================

-- Validate a key + get the game's enabled scripts. Returns the parsed table on
-- success, or (nil, errCode[, data]) on failure. errCode "wrong_game" = key is
-- bound to a different game.
function M.validateKeyNew(key)
    key = cleanKey(key)
    if key == "" then return nil, "empty" end
    if not _request then return nil, "no_request" end
    local url = M.VALIDATE_URL
        .. "?key="      .. HttpService:UrlEncode(key)
        .. "&hwid="     .. HttpService:UrlEncode(tostring(M.hwid))
        .. "&place_id=" .. tostring(game.PlaceId)
    local ok, res = pcall(function()
        return _request({ Url = url, Method = "GET", Headers = { ["Content-Type"] = "application/json" } })
    end)
    if not ok or type(res) ~= "table" then return nil, "network" end
    local body = res.Body or res.body
    if type(body) ~= "string" or body == "" then return nil, "bad_response" end
    local dok, data = pcall(_jsonDecode_ref, HttpService, body)
    if not dok or type(data) ~= "table" then return nil, "bad_response" end
    if data.success ~= true then
        return nil, tostring(data.code or data.message or "invalid"), data
    end
    return data
end

-- Load the selector module and show the picker (auto-runs when only one script).
function M.showSelector(scripts)
    if type(scripts) ~= "table" or #scripts == 0 then return false end
    if not safeToLoad() then return false end
    local ok, Sel = pcall(function() return loadstring(game:HttpGet(M.SELECTOR_URL))() end)
    if ok and type(Sel) == "table" and type(Sel.show) == "function" then
        pcall(Sel.show, scripts)
        return true
    end
    return false
end

-- Local key persistence so a returning user auto-loads without re-entering.
local KEY_FILE = "combowick_key.txt"
function M.loadSavedKey()
    local ok, k = pcall(function()
        if isfile and isfile(KEY_FILE) and readfile then return readfile(KEY_FILE) end
        return nil
    end)
    if ok and type(k) == "string" then return cleanKey(k) end
    return ""
end
function M.saveKeyLocal(key)
    pcall(function() if writefile then writefile(KEY_FILE, tostring(key)) end end)
end
function M.clearSavedKey()
    pcall(function() if delfile and isfile and isfile(KEY_FILE) then delfile(KEY_FILE) end end)
end

-- Startup auto-load: if a saved key still validates for THIS game, show the selector.
-- Returns true (and loads) when a valid key + scripts exist; false otherwise.
function M.tryNewKey()
    local key = M.loadSavedKey()
    if key == "" then return false end
    local data = M.validateKeyNew(key)
    if type(data) ~= "table" then return false end
    local scripts = data.scripts or {}
    if #scripts == 0 then return false end
    return M.showSelector(scripts)
end

return M
