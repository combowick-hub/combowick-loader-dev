if _G.COMBOWICK_ACTIVE then return end

local HttpService = game:GetService("HttpService")
local Players     = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

pcall(function() if not game:IsLoaded() then game.Loaded:Wait() end end)
do
    local t = tick()
    while not LocalPlayer and (tick() - t) < 10 do task.wait(); LocalPlayer = Players.LocalPlayer end
end
if not LocalPlayer then return end
if not game.PlaceId or game.PlaceId == 0 then return end

local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"

-- ===== INLINED MODULE (combowick_module.lua) — combined build for direct execution =====
local M = (function()
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

end)()
-- ===== END INLINED MODULE =====

if not M then warn("[COMBOWICK] module failed to init"); return end

-- [i18n] Translated builds set M.EXPIRED_TITLE / M.EXPIRED_SUB here (English uses module defaults).

M.queueOnTeleport()

-- [DEV] Vault whitelist path removed (it auto-loaded INK in every game). Straight to
-- the new key path: if a saved key still validates for this game, load its scripts
-- (auto-run 1, picker for 2+) and skip the free-session flow. Returning key users.
if M.tryNewKey() then return end

local preCheck = M.withRetry(M.checkSession, M.hwid)
if preCheck ~= nil and preCheck.status ~= "game_not_allowed" then
    if M.tryFreeSession(preCheck) then return end
end
preCheck = preCheck or { status = "error", remaining = 0, disabled = false }

do
    pcall(function() if getgenv and getgenv().Library then getgenv().Library:Unload() end end)
    local targets = {}
    if gethui then local ok, h = pcall(gethui); if ok and h then table.insert(targets, h) end end
    table.insert(targets, game:GetService("CoreGui"))
    for _, target in ipairs(targets) do
        for _, v in ipairs(target:GetChildren()) do
            local n = v.Name
            if n == "Obsidian" or n == "ObsidianLoading" or n == "LinoriaGui" then pcall(v.Destroy, v) end
        end
    end
end

local Library      = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager  = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()
local Options      = Library.Options

local VaultModule       = M.VaultModule
local execPremiumScript = M.execPremiumScript

local function safeSet(lbl, text) pcall(function() lbl:SetText(text) end) end

local Window = Library:CreateWindow({
    Title = "COMBOWICK", Footer = "Free Version", NotifySide = "Right",
    ShowCustomCursor = false, AutoShow = true, Size = UDim2.fromOffset(560, 340),
})
local Tabs = {
    Main    = Window:AddTab("Main",        "user"),
    Key     = Window:AddTab("Premium Key", "key"),
    Suggest = Window:AddTab("Suggestions", "message-square"),
    UI      = Window:AddTab("UI Settings", "settings"),
}

if M.looksTampered() then
    Library:Notify({Title="⚠️ Tampering", Description="Modified functions were detected in your executor.", Time=6})
end

local preRemaining = tonumber(preCheck.remaining) or 0
local preStatus      = preCheck.status
local gameDisabled   = preCheck.disabled == true
local gameUnsupported = preStatus == "game_not_allowed"

local InfoGroup = Tabs.Main:AddLeftGroupbox("Free Session", "info")
local lSession  = InfoGroup:AddLabel(
    (not gameDisabled and (preStatus == "allowed" or preStatus == "session_active") and preRemaining > 0)
        and string.format("Session time: %s", M.formatTime(preRemaining)) or "Session time: —", true)
local lCooldown = InfoGroup:AddLabel(
    (preStatus == "cooldown" and preRemaining > 0)
        and string.format("Cooldown: %s", M.formatTime(preRemaining)) or "Cooldown: —", true)
if gameUnsupported then
    InfoGroup:AddLabel("🚫 This game is not supported yet.", true)
elseif gameDisabled then
    InfoGroup:AddLabel("⛔ The free version is not available in this game.", true)
else
    InfoGroup:AddLabel("The free version is not available in every game.", true)
end
InfoGroup:AddDivider()
InfoGroup:AddLabel("Upgrade to an 11-hour key to remove the cooldown.", true)
InfoGroup:AddButton({
    Text = "Copy Key Link", Tooltip = "combowick.com/verify/provider-select",
    Func = function()
        pcall(function() setclipboard(M.KEY_URL) end)
        Library:Notify({Title="COMBOWICK", Description="Link copied. Paste it into your browser.", Time=4})
    end,
})
local StatusGroup = Tabs.Main:AddRightGroupbox("Status", "shield")
local statusLabel = StatusGroup:AddLabel("Checking...", true)
local timerLabel  = StatusGroup:AddLabel("", true)
local hintLabel   = StatusGroup:AddLabel("", true)


local savedKey = M.loadSavedKey()
local keyInputValue = savedKey

local KeyGroup = Tabs.Key:AddLeftGroupbox("Enter Your Key")
KeyGroup:AddInput("KeyInput", {
    Default          = savedKey,
    Numeric          = false,
    Finished         = false,
    ClearTextOnFocus = false,
    Text             = "Key 🔑",
    Placeholder      = "Paste your key here...",
    Callback         = function(v) keyInputValue = v end,
})
local function submitKey(key)
    key = M.cleanKey(key)
    if key == "" then
        Library:Notify({Title="⚠️ No Key Entered", Description="Please enter your key.", Time=3})
        return
    end
    Library:Notify({Title="🔑 Checking", Description="Validating your key...", Time=2})

    -- NEW backend: validate the key + get this game's scripts in one call.
    local data, err = M.validateKeyNew(key)
    if type(data) ~= "table" then
        local msg = "That key is not valid. Please check it and try again."
        if err == "wrong_game" then
            msg = "This key is for a different game. Get a key for this game."
        elseif err == "network" or err == "no_request" then
            msg = "Network error. Please try again."
        end
        Library:Notify({Title="❌ Invalid Key", Description=msg, Time=5})
        return
    end

    local scripts = data.scripts or {}
    if #scripts == 0 then
        Library:Notify({Title="🔓 Key Valid", Description="No scripts are set for this game yet.", Time=5})
        return
    end

    -- Valid — remember the key for next time, close this GUI, show the selector.
    M.saveKeyLocal(key)
    Library:Notify({
        Title = "🔓 Key Valid",
        Description = (#scripts == 1) and "Loading script..." or "Choose a script...",
        Time = 3,
    })
    task.wait(0.4)
    pcall(function() Library:Unload() end)
    M.showSelector(scripts)
end

local function readKeyFromBox()
    local raw
    pcall(function()
        local holder = Options and Options.KeyInput and Options.KeyInput.Holder
        local box = holder and holder:FindFirstChildOfClass("TextBox")
        if box then raw = box.Text end
    end)
    local key = M.cleanKey(raw)
    if key == "" then key = M.cleanKey(Options and Options.KeyInput and Options.KeyInput.Value) end
    if key == "" then key = M.cleanKey(keyInputValue) end
    return key
end

KeyGroup:AddButton({
    Text = "✅ Submit Key",
    Func = function() submitKey(readKeyFromBox()) end,
})
KeyGroup:AddButton({
    Text = "🔗 Get Key",
    Func = function()
        pcall(function() setclipboard(M.KEY_URL) end)
        Library:Notify({Title="Copied", Description="Key link copied.", Time=2})
    end,
})

local HWIDGroup = Tabs.Key:AddRightGroupbox("Your HWID")
HWIDGroup:AddLabel(M.hwid, true)
HWIDGroup:AddButton({
    Text = "📋 Copy HWID",
    Func = function()
        pcall(function() setclipboard(M.hwid) end)
        Library:Notify({Title="Copied", Description="HWID copied.", Time=2})
    end,
})
HWIDGroup:AddButton({
    Text = "🔒 Copy Encrypted HWID",
    Func = function()
        pcall(function() setclipboard(M.encryptedHWID) end)
        Library:Notify({Title="Copied", Description="Encrypted HWID copied.", Time=2})
    end,
})

local FEEDBACK_COOLDOWN, lastFeedback = 20, 0
local ERRMAP = {
    empty = "The message is empty.", no_links = "Links are not allowed.",
    too_long = "The message is too long (500 characters maximum).", rate_limited = "You have reached the limit of 3 messages. Please try again later.",
    busy = "The server is busy. Please try again.", banned = "You are not allowed to send feedback.",
    discord_error = "Sending failed. Please try again.", network = "Network error.",
    no_request = "Your executor cannot send requests.", bad_response = "The server returned an unexpected response.",
    unreachable = "Your executor cannot reach the server (TLS error). Please try a different executor.",
}
local FG = Tabs.Suggest:AddLeftGroupbox("Suggestions / Help", "message-square")
FG:AddDropdown("FeedbackType", {Text = "Type", Values = {"Suggestion", "Bug", "Help"}, Default = "Suggestion", Callback = function() end})
FG:AddInput("FeedbackMsg", {Default = "", Numeric = false, Finished = false, ClearTextOnFocus = false, Text = "Message", Placeholder = "Type your message (500 characters maximum, no links)"})
local fbStatus = FG:AddLabel("", true)
FG:AddButton({
    Text = "📨 Send",
    Func = function()
        local now = tick()
        if now - lastFeedback < FEEDBACK_COOLDOWN then
            safeSet(fbStatus, string.format("Please wait %d seconds before sending again.", math.ceil(FEEDBACK_COOLDOWN - (now - lastFeedback))))
            return
        end
        local ftype = tostring((Options.FeedbackType and Options.FeedbackType.Value) or "Suggestion"):lower()
        local msg   = M.trim((Options.FeedbackMsg and Options.FeedbackMsg.Value) or "")
        if msg == "" then safeSet(fbStatus, "The message is empty."); return end
        if #msg > 500 then safeSet(fbStatus, "The message is too long (500 characters maximum)."); return end
        local low = msg:lower()
        if low:find("http", 1, true) or low:find("discord.gg", 1, true) or low:find("www.", 1, true) or low:find(".gg/", 1, true) then
            safeSet(fbStatus, "Links are not allowed."); return
        end
        safeSet(fbStatus, "Sending...")
        task.spawn(function()
            local sok, err = M.sendFeedback(ftype, msg, (preCheck and preCheck.session_token) or "")
            if sok then
                lastFeedback = tick()
                safeSet(fbStatus, "✅ Sent. Thank you!")
                pcall(function() Options.FeedbackMsg:SetValue("") end)
                Library:Notify({Title = "COMBOWICK", Description = "Your feedback was sent. Thank you!", Time = 3})
            else
                safeSet(fbStatus, ERRMAP[err] or ("Failed to send: " .. tostring(err)))
            end
        end)
    end,
})
FG:AddLabel("Maximum 3 messages per hour. No links or mentions.", true)

local HelpGroup = Tabs.Suggest:AddRightGroupbox("Help / FAQ", "life-buoy")
HelpGroup:AddButton({
    Text = "💬 Join Discord",
    Tooltip = M.DISCORD_INVITE,
    Func = function()
        pcall(function() setclipboard(M.DISCORD_INVITE) end)
        Library:Notify({Title = "COMBOWICK", Description = "Discord link copied. Paste it into your browser.", Time = 4})
    end,
})
HelpGroup:AddDivider()
HelpGroup:AddLabel("❓ How do I get premium?\nGet a key at combowick.com/verify, then paste it into the Premium Key tab. One tap is enough.", true)
HelpGroup:AddLabel("⏳ Why am I on cooldown?\nThe free version has a waiting period between sessions. An 11-hour key removes it completely.", true)
HelpGroup:AddLabel("🎮 It is not working in my game.\nThe free version is not available in every game. Check our Discord for the list of supported games.", true)
HelpGroup:AddLabel("🔑 What is my HWID?\nIt is your hardware ID. Copy it from the Premium Key tab if support asks for it.", true)

task.spawn(function()
    safeSet(statusLabel, "Authenticating...")

    local result = M.withRetry(M.checkSession, M.hwid)

    if result == nil then
        safeSet(statusLabel, "Status: Failed")
        Library:Notify({Title="COMBOWICK", Description="The session check failed.", Time=5})

    elseif result.status == "allowed" or result.status == "session_active" then
        if result.disabled then
            safeSet(statusLabel, "⛔ Game Disabled")
            safeSet(hintLabel, "The free version is not available here. Get a key.")
            Library:Notify({Title="COMBOWICK", Description="The free version is disabled for this game. Please use a key.", Time=6})
            return
        end
        local token = result.session_token
        if type(token) ~= "string" or #token < 20 then
            safeSet(statusLabel, "Status: Failed")
        else
            safeSet(statusLabel, "Status: Authenticated")
            Library:Notify({Title="COMBOWICK", Description="You are authenticated.", Time=3})
            _G.COMBOWICK_FREE   = true
            _G.COMBOWICK_ACTIVE = true
            local remaining = tonumber(result.remaining) or 0
            task.spawn(function()
                while remaining > 0 do
                    local fmt = M.formatTime(remaining)
                    safeSet(timerLabel, string.format("Time remaining: %s", fmt))
                    safeSet(lSession, string.format("Session time: %s", fmt))
                    task.wait(1); remaining = remaining - 1
                end
                safeSet(timerLabel, "The session has expired.")
                safeSet(lSession, "Session time: expired")
                _G.COMBOWICK_ACTIVE = false
                pcall(function() Library:Unload() end)
                M.showExpiredPopup(function() M.reloadExist() end)
            end)
            local scriptUrl = M.getScriptForGame(token)
            if M.loadFreeScript(scriptUrl, token) then task.wait(2); pcall(function() Library:Unload() end) end
        end

    elseif result.status == "cooldown" then
        local remaining = tonumber(result.remaining) or 0
        safeSet(statusLabel, "On Cooldown")
        safeSet(hintLabel, "Get an 11-hour key, or wait for the cooldown to finish.")
        Library:Notify({Title="COMBOWICK", Description="You are on cooldown. Get a key to skip the wait.", Time=6})
        task.spawn(function()
            while remaining > 0 do
                local fmt = M.formatTime(remaining)
                safeSet(timerLabel, string.format("Cooldown: %s", fmt))
                safeSet(lCooldown, string.format("Cooldown: %s", fmt))
                task.wait(1); remaining = remaining - 1
            end
            safeSet(timerLabel, "The cooldown has finished.")
            safeSet(lCooldown, "Cooldown: finished")
            safeSet(hintLabel, "")
            Library:Notify({Title="COMBOWICK", Description="The cooldown has finished. Reloading...", Time=3})
            pcall(function() Library:Unload() end)
            task.wait(0.5)
            M.reloadExist()
        end)

    elseif result.status == "throttled" then
        local remaining = tonumber(result.remaining) or 0
        safeSet(statusLabel, "Too Many Requests")
        safeSet(hintLabel, "Too many requests. Please wait.")
        Library:Notify({Title="COMBOWICK", Description="Too many requests. Please wait a moment.", Time=5})
        task.spawn(function()
            while remaining > 0 do
                safeSet(timerLabel, string.format("Retry in %s", M.formatTime(remaining)))
                task.wait(1); remaining = remaining - 1
            end
            safeSet(timerLabel, "Reloading...")
            safeSet(hintLabel, "")
            pcall(function() Library:Unload() end)
            task.wait(0.5)
            M.reloadExist()
        end)

    elseif result.status == "disabled" then
        safeSet(statusLabel, "Service Paused")
        safeSet(hintLabel, "COMBOWICK is temporarily offline.")
        Library:Notify({Title="COMBOWICK", Description="The service is currently disabled. Please try again later.", Time=6})

    elseif result.status == "banned" then
        safeSet(statusLabel, "Banned")
        Library:Notify({Title="COMBOWICK", Description="You are banned.", Time=5})

    elseif result.status == "game_not_allowed" then
        safeSet(statusLabel, "🚫 Game Not Supported")
        safeSet(hintLabel, "This game is not supported yet. Premium keys still work if a script is available.")
        Library:Notify({Title="COMBOWICK", Description="This game is not supported yet.", Time=6})

    else
        safeSet(statusLabel, "Error")
        safeSet(hintLabel, "Could not reach the server. Please run the script again.")
        Library:Notify({Title="COMBOWICK", Description=tostring(result.message or "An unknown error occurred."), Time=5})
    end
end)

local MenuGroup = Tabs.UI:AddLeftGroupbox("Menu", "wrench")
MenuGroup:AddToggle("ShowCustomCursor", {Text="Custom Cursor", Default=false, Callback=function(v) Library.ShowCustomCursor = v end})
MenuGroup:AddLabel("Menu keybind"):AddKeyPicker("MenuKeybind", {Default="RightShift", NoUI=true, Text="Menu keybind"})
MenuGroup:AddButton({Text="Unload", Func=function() pcall(function() Library:Unload() end) end})
Library.ToggleKeybind = Options.MenuKeybind

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({"MenuKeybind"})
ThemeManager:SetFolder("COMBOWICK")
SaveManager:SetFolder("COMBOWICK/game")
SaveManager:BuildConfigSection(Tabs.UI)
ThemeManager:ApplyToTab(Tabs.UI)
SaveManager:LoadAutoloadConfig()
