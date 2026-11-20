local ADDON, ns = ...

local POWER_INFUSION = 10060
local PI_DURATION = 15
local MEDIA = "Interface\\AddOns\\MLGPowerInfusion\\Media\\"
local SOUND = MEDIA .. "mlg.mp3"
-- Blizzard stops aura sounds after 5 seconds, so only the intro is registered and the addon plays the rest.
local SOUND_INTRO = MEDIA .. "mlg_intro.ogg"
local SOUND_REST = MEDIA .. "mlg_rest.ogg"
local REST_AT = 4.85
local GAIN_GUARD = 10
local CAST_SETTLE = 0.3
local LOGO = MEDIA .. "logo"
local LOGO_ICON = "|T" .. LOGO .. ":16:16|t"

local WIDTH, HEIGHT = 600, 64
local BG_PAD_X, BG_PAD_Y = 12, 6
local ICON_SIZE, ICON_INSET = 56, 4
local TEXT_INSET = ICON_INSET + ICON_SIZE + 10
local TEXT_R, TEXT_G, TEXT_B = 1, 0.85, 0.1
local FADE_IN, HOLD, FADE_OUT = 0.15, 2.75, 0.6
local GONE_AT = PI_DURATION - (FADE_IN + HOLD + FADE_OUT)

local CHANNELS = { master = "Master", sfx = "SFX", music = "Music", ambience = "Ambience", dialog = "Dialog" }
local DEFAULTS = { enabled = true, alert = true, channel = "Master" }

local db, lastMessage, soundID

local function Print(msg)
    print(LOGO_ICON .. " |cffff66ccMLG Power Infusion|r " .. msg)
end

local function Debug(msg)
    if db and db.debug then
        Print("|cff888888[" .. (InCombatLockdown() and "combat" or "no combat") .. "]|r " .. msg)
    end
end

local function PickMessage()
    local messages = ns.messages
    local msg
    repeat
        msg = messages[math.random(#messages)]
    until msg ~= lastMessage or #messages < 2
    lastMessage = msg
    return msg
end

local function MessageText(msg)
    -- Forever's UnitName also returns the surname, which gsub would take as its repeat count.
    local name = UnitName("player")
    return (msg.text:gsub("{player}", name))
end

local testBanner = CreateFrame("Frame", nil, UIParent)
testBanner:SetSize(WIDTH, HEIGHT)
testBanner:SetPoint("TOP", 0, -140)
testBanner:SetFrameStrata("HIGH")
testBanner:Hide()

local bg = testBanner:CreateTexture(nil, "BACKGROUND")
bg:SetPoint("TOPLEFT", -BG_PAD_X, BG_PAD_Y)
bg:SetPoint("BOTTOMRIGHT", BG_PAD_X, -BG_PAD_Y)
bg:SetColorTexture(0, 0, 0, 0.55)

local function CreateLogo(parent, anchor)
    local tex = parent:CreateTexture(nil, "ARTWORK")
    tex:SetSize(ICON_SIZE, ICON_SIZE)
    tex:SetPoint("LEFT", anchor, "LEFT", ICON_INSET, 0)
    tex:SetTexture(LOGO)
    return tex
end

CreateLogo(testBanner, testBanner)

local function CreateBatchest(parent, anchor)
    local tex = parent:CreateTexture(nil, "ARTWORK")
    tex:SetSize(ICON_SIZE, ICON_SIZE)
    tex:SetPoint("RIGHT", anchor, "RIGHT", -ICON_INSET, 0)
    tex:SetTexture(MEDIA .. "batchest")
    tex.flipbook = tex:CreateAnimationGroup()
    tex.flipbook:SetLooping("REPEAT")
    local frames = tex.flipbook:CreateAnimation("FlipBook")
    frames:SetFlipBookRows(4)
    frames:SetFlipBookColumns(8)
    frames:SetFlipBookFrames(21)
    frames:SetDuration(21 * 0.04)
    return tex
end

local batchest = CreateBatchest(testBanner, testBanner)

local testText = testBanner:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
testText:SetPoint("LEFT", TEXT_INSET, 0)
testText:SetPoint("RIGHT", -TEXT_INSET, 0)
testText:SetTextColor(TEXT_R, TEXT_G, TEXT_B)
testText:SetShadowOffset(2, -2)

local fade = testBanner:CreateAnimationGroup()
local fadeIn = fade:CreateAnimation("Alpha")
fadeIn:SetFromAlpha(0)
fadeIn:SetToAlpha(1)
fadeIn:SetDuration(FADE_IN)
local fadeOut = fade:CreateAnimation("Alpha")
fadeOut:SetFromAlpha(1)
fadeOut:SetToAlpha(0)
fadeOut:SetStartDelay(FADE_IN + HOLD)
fadeOut:SetDuration(FADE_OUT)
fade:SetScript("OnFinished", function()
    batchest.flipbook:Stop()
    testBanner:Hide()
end)

local restTimer

local function PlayRest(delay)
    if restTimer then restTimer:Cancel() end
    restTimer = C_Timer.NewTimer(math.max(delay, 0), function()
        restTimer = nil
        PlaySoundFile(SOUND_REST, db.channel)
    end)
end

-- Mirrors what a real PI plays on this client.
local function PlaySound()
    if soundID then
        PlaySoundFile(SOUND_INTRO, db.channel)
        PlayRest(REST_AT)
    else
        PlaySoundFile(SOUND, db.channel)
    end
end

local function ShowBanner()
    local msg = PickMessage()
    testText:SetText(MessageText(msg))
    batchest:SetShown(msg.batchest == true)
    fade:Stop()
    batchest.flipbook:Restart()
    testBanner:Show()
    fade:Play()
end

local function PlayMLG()
    PlaySound()
    if db.alert then ShowBanner() end
end

local auraContainer, auraBanner

local function BannerString(banner, msg)
    local s = MessageText(msg)
    if not banner.batchest then
        s = "|T" .. LOGO .. ":32:32|t  " .. s
        if msg.batchest then
            s = s .. "  |T" .. MEDIA .. "batchest:32:32:0:0:512:256:0:64:0:64|t"
        end
    end
    return s
end

local function ShowBatchest(banner, show)
    banner.batchest:SetShown(show)
    banner.text:SetPoint("BOTTOMRIGHT", show and -TEXT_INSET or 0, 0)
end

local function BindAuraText(banner)
    local msg = PickMessage()
    if banner.batchest then pcall(ShowBatchest, banner, msg.batchest == true) end
    return pcall(function()
        banner.formatter:SetBreakpoints({
            { threshold = 0, format = "" },
            { threshold = GONE_AT, format = (BannerString(banner, msg):gsub("%%", "%%%%")) },
        })
        banner.button:SetDurationText(banner.text, { binding = banner.binding })
    end)
end

local function CreateBackground(banner, button)
    local clip = CreateFrame("Frame", nil, banner)
    clip:SetPoint("TOPLEFT", -BG_PAD_X, BG_PAD_Y)
    clip:SetPoint("BOTTOMRIGHT", BG_PAD_X, -BG_PAD_Y)
    clip:SetClipsChildren(true)

    local clipW = WIDTH + 2 * BG_PAD_X
    local barW = clipW * PI_DURATION / FADE_OUT
    local bar = CreateFrame("StatusBar", nil, clip)
    bar:SetPoint("TOP")
    bar:SetPoint("BOTTOM")
    bar:SetPoint("LEFT", clip, "LEFT", clipW - barW * (GONE_AT + FADE_OUT) / PI_DURATION, 0)
    bar:SetWidth(barW)
    bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    bar:SetStatusBarColor(0, 0, 0, 0.55)
    button:SetDurationBar(bar, {
        interpolation = Enum.StatusBarInterpolation.Immediate,
        direction = Enum.StatusBarTimerDirection.RemainingTime,
    })
    return bar
end

local function CreateAuraArt(banner, bar)
    local clip = CreateFrame("Frame", nil, banner)
    clip:SetPoint("TOPLEFT")
    clip:SetPoint("BOTTOM")
    clip:SetPoint("RIGHT", bar:GetStatusBarTexture(), "RIGHT")
    clip:SetClipsChildren(true)
    clip:SetFrameLevel(banner:GetFrameLevel() + 5)
    CreateLogo(clip, banner)
    local tex = CreateBatchest(clip, banner)
    tex.flipbook:Play()
    return tex
end

local function CreateTextBinding(banner)
    local curve = C_CurveUtil.CreateColorCurve()
    curve:AddPoint(GONE_AT, CreateColor(TEXT_R, TEXT_G, TEXT_B, 0))
    curve:AddPoint(GONE_AT + FADE_OUT, CreateColor(TEXT_R, TEXT_G, TEXT_B, 1))
    banner.formatter = C_StringUtil.CreateNumericRuleFormatter()
    banner.binding = C_DurationUtil.CreateDurationTextBinding()
    banner.binding:SetFormatter(banner.formatter)
    banner.binding:SetTextColorCurve(curve, Enum.DurationTextBindingProperty.RemainingDuration)
    pcall(banner.binding.SetUpdateInterval, banner.binding, 0.05)
    pcall(banner.binding.SetFontString, banner.binding, banner.text)
end

local function InitAuraButton(button)
    if auraBanner then return end
    button:EnableMouse(false)

    local banner = CreateFrame("Frame", nil, button, "DisableUntrustedLayoutScriptsTemplate")
    banner:SetSize(WIDTH, HEIGHT)
    banner:SetPoint("CENTER", auraContainer)
    banner.button = button

    local bgOk, bar = pcall(CreateBackground, banner, button)
    if bgOk then
        local ok, tex = pcall(CreateAuraArt, banner, bar)
        banner.batchest = ok and tex or nil
    end

    local textHost = CreateFrame("Frame", nil, banner)
    textHost:SetAllPoints()
    textHost:SetFrameLevel(banner:GetFrameLevel() + 5)

    banner.text = textHost:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    banner.text:SetPoint("TOPLEFT", banner.batchest and TEXT_INSET or 0, 0)
    banner.text:SetPoint("BOTTOMRIGHT")
    banner.text:SetTextColor(TEXT_R, TEXT_G, TEXT_B)
    banner.text:SetShadowOffset(2, -2)

    if not (pcall(CreateTextBinding, banner) and BindAuraText(banner)) then
        banner.formatter = nil
        local msg = PickMessage()
        banner.text:SetText(BannerString(banner, msg))
        if banner.batchest then pcall(ShowBatchest, banner, msg.batchest == true) end
    end
    auraBanner = banner
end

local function CreateAuraContainer()
    C_AddOns.LoadAddOn("Blizzard_AuraContainer")
    local ok, container = pcall(CreateFrame, "AuraContainer", nil, UIParent, "CustomAuraContainerTemplate")
    if not (ok and container) then return end
    container:SetPoint("TOP", 0, -140)
    container:SetSize(WIDTH, HEIGHT)
    container:SetFrameStrata("HIGH")
    container:EnableMouse(false)
    auraContainer = container

    local slotOk, slot = pcall(container.AddAuraSlot, container, "mlgpi", "HELPFUL", {
        maxFrameCount = 1,
        initializeFrame = InitAuraButton,
        candidateFilters = { includeSpellIDs = { [POWER_INFUSION] = true } },
        layout = { elementWidth = WIDTH, elementHeight = HEIGHT },
    })
    if not slotOk then
        auraContainer = nil
        return
    end
    if type(slot) == "table" and slot.SetPoint then InitAuraButton(slot) end
end

local function RefreshAuraBanner()
    if not auraContainer then CreateAuraContainer() end
    if not auraContainer then return end
    local on = db.enabled and db.alert
    pcall(auraContainer.SetEnabled, auraContainer, on)
    pcall(auraContainer.SetUnit, auraContainer, on and "player" or nil)
    if auraContainer.UpdateAllAuras then pcall(auraContainer.UpdateAllAuras, auraContainer) end
end

local function CanRegisterSound()
    return C_UnitAuras and C_UnitAuras.AddAuraSound and Enum.UnitAuraSoundTrigger
end

local function RegisterSound()
    if not CanRegisterSound() then return end
    local newID
    if db.enabled then
        local ok, id = pcall(C_UnitAuras.AddAuraSound, Enum.UnitAuraSoundTrigger.Added, {
            spellID = POWER_INFUSION, unitToken = "player", soundFileName = SOUND_INTRO, outputChannel = db.channel,
        })
        if not (ok and type(id) == "number") then return end
        newID = id
    end
    if soundID then pcall(C_UnitAuras.RemoveAuraSound, soundID) end
    soundID = newID
end

-- In combat the game hides PI from addons (the read fails or says it is off), so the player's own PI cast
-- is the signal there. Clients without aura sounds get the whole track from here.
local hadPI, lastGain, lastRead, castsHidden, castOnOther = false, 0, nil, false, false

local function ReadPowerInfusion()
    local ok, has, age = pcall(function()
        local aura = C_UnitAuras.GetPlayerAuraBySpellID(POWER_INFUSION)
        if issecretvalue and issecretvalue(aura) then error("secret") end
        if not aura then return false end
        return true, GetTime() - (aura.expirationTime - aura.duration)
    end)
    local read = not ok and "hidden" or has and "on" or "off"
    if read ~= lastRead then
        lastRead = read
        Debug("PI aura read: " .. read)
    end
    return ok, has, age
end

local function OnPowerInfusion(source, age)
    local now = GetTime()
    if now - lastGain < GAIN_GUARD then return end
    if soundID then
        if age >= REST_AT then return end
        PlayRest(REST_AT - age)
    else
        PlaySoundFile(SOUND, db.channel)
        if db.alert and not auraContainer then ShowBanner() end
    end
    lastGain = now
    Debug(("PI detected by %s, %.2fs after it landed"):format(source, age))
end

local function CheckPowerInfusion()
    if not db.enabled then return end
    local ok, has, age = ReadPowerInfusion()
    if not ok then return end
    if has and not hadPI then OnPowerInfusion("aura", age) end
    hadPI = has
end

local function IsPowerInfusion(spellID)
    return pcall(function()
        if issecretvalue and issecretvalue(spellID) then error("secret") end
        return spellID == POWER_INFUSION
    end)
end

-- The sent target is only a name, and with an enemy targeted it names the enemy while PI lands on the
-- player. A name matching one of these units is judged by whether the player can buff it; any other
-- name that is not the player's own came from a unit that is not checked here (a party or raid token,
-- say), which can only be an ally.
local CAST_UNITS = { "target", "focus", "mouseover" }

local function UnitHasName(unit, name)
    if not UnitExists(unit) then return false end
    -- The second return is the surname on Forever and the realm on retail.
    local first, second = UnitName(unit)
    if name == first or name == GetUnitName(unit, true) then return true end
    return second ~= nil and second ~= "" and name == first .. " " .. second
end

local function OnSpellcastSent(target, spellID)
    local ok, isPI = IsPowerInfusion(spellID)
    if not (ok and isPI) then return end
    local nameOk, other = pcall(function()
        if issecretvalue and issecretvalue(target) then error("secret") end
        if not target or target == "" then return false end
        for _, unit in ipairs(CAST_UNITS) do
            if UnitHasName(unit, target) then
                return UnitCanAssist("player", unit) and not UnitIsUnit(unit, "player")
            end
        end
        return not UnitHasName("player", target)
    end)
    castOnOther = nameOk and other == true
    Debug("PI cast sent at " .. (nameOk and (castOnOther and "an ally" or "you") or "a hidden target"))
end

local function OnSpellcast(spellID)
    local ok, isPI = IsPowerInfusion(spellID)
    if not ok then
        if not castsHidden then Debug("your spell casts are hidden") end
        castsHidden = true
        return
    end
    castsHidden = false
    if not isPI or not db.enabled then return end
    Debug("saw your PI cast" .. (castOnOther and " (on an ally)" or ""))
    local onOther = castOnOther
    castOnOther = false
    C_Timer.After(CAST_SETTLE, function()
        local readable, has = ReadPowerInfusion()
        if readable and has then
            CheckPowerInfusion()
        elseif InCombatLockdown() and not onOther then
            OnPowerInfusion("cast", CAST_SETTLE)
        end
    end)
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterUnitEvent("UNIT_AURA", "player")
events:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
events:RegisterUnitEvent("UNIT_SPELLCAST_SENT", "player")
events:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        if ... ~= ADDON then return end
        MLGPowerInfusionDB = MLGPowerInfusionDB or {}
        db = MLGPowerInfusionDB
        for k, v in pairs(DEFAULTS) do
            if db[k] == nil then db[k] = v end
        end
        self:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_ENTERING_WORLD" then
        RefreshAuraBanner()
        if not soundID then RegisterSound() end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if not soundID then RegisterSound() end
        if auraBanner and auraBanner.formatter then BindAuraText(auraBanner) end
        CheckPowerInfusion()
    elseif event == "UNIT_AURA" and db then
        CheckPowerInfusion()
    elseif event == "UNIT_SPELLCAST_SENT" and db then
        local _, target, _, spellID = ...
        OnSpellcastSent(target, spellID)
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" and db then
        local _, _, spellID = ...
        OnSpellcast(spellID)
    end
end)

local function Toggle(key, label)
    db[key] = not db[key]
    Print(label .. " " .. (db[key] and "on" or "off"))
    RefreshAuraBanner()
end

SLASH_MLGPOWERINFUSION1 = "/mlgpi"
SlashCmdList.MLGPOWERINFUSION = function(msg)
    msg = strlower(strtrim(msg or ""))
    if msg == "test" then
        PlayMLG()
    elseif msg == "toggle" then
        Toggle("enabled", "addon")
        RegisterSound()
    elseif msg == "alert" then
        Toggle("alert", "on-screen alert")
    elseif CHANNELS[msg] then
        db.channel = CHANNELS[msg]
        Print("sound channel set to " .. db.channel)
        RegisterSound()
    elseif msg == "debug" then
        db.debug = not db.debug
        Print("debug " .. (db.debug and "on" or "off"))
    elseif msg == "status" then
        if soundID then
            Print("sound: registered with Blizzard (plays in combat; the rest of the track follows when PI is detected)")
        elseif CanRegisterSound() then
            Print("sound: not registered yet (retries out of combat)")
        else
            Print("sound: this client can't register aura sounds; plays when PI lands out of combat")
        end
        Print("banner: " .. (auraContainer and "Blizzard aura frame (shows in combat)" or "out of combat only"))
    else
        Print("commands:")
        print("  /mlgpi test - play the sound and alert")
        print("  /mlgpi status - show what this client supports")
        print("  /mlgpi debug - print how PI is being detected")
        print("  /mlgpi toggle - turn the addon on/off")
        print("  /mlgpi alert - turn the on-screen alert on/off")
        print("  /mlgpi master|sfx|music|ambience|dialog - volume channel")
    end
end

function MLGPowerInfusion_OnCompartmentClick()
    PlayMLG()
end

function MLGPowerInfusion_OnCompartmentEnter(_, button)
    GameTooltip:SetOwner(button, "ANCHOR_LEFT")
    GameTooltip:AddLine(LOGO_ICON .. " MLG Power Infusion")
    GameTooltip:AddLine(db.enabled and "|cff00ff00Enabled|r" or "|cffff0000Disabled|r")
    GameTooltip:AddLine("Click to test.", 1, 1, 1)
    GameTooltip:AddLine("/mlgpi for commands", 0.7, 0.7, 0.7)
    GameTooltip:Show()
end

function MLGPowerInfusion_OnCompartmentLeave()
    GameTooltip:Hide()
end
