local ADDON, ns = ...

local POWER_INFUSION = 10060
local PI_DURATION = 15
local MEDIA = "Interface\\AddOns\\PowerInfusionMLG\\Media\\"
local SOUND = MEDIA .. "mlg.mp3"
local LOGO = MEDIA .. "logo"
local LOGO_ICON = "|T" .. LOGO .. ":16:16|t"

local WIDTH, HEIGHT = 600, 64
local BG_PAD_X, BG_PAD_Y = 12, 6
local ICON_SIZE, ICON_INSET = 56, 4
local TEXT_INSET = ICON_INSET + ICON_SIZE + 10 -- room for an icon beside the text
local TEXT_R, TEXT_G, TEXT_B = 1, 0.85, 0.1
local FADE_IN, HOLD, FADE_OUT = 0.15, 2.75, 0.6 -- gone 3.5s after PI lands
local GONE_AT = PI_DURATION - (FADE_IN + HOLD + FADE_OUT) -- PI time remaining when the banner is gone

local CHANNELS = { master = "Master", sfx = "SFX", music = "Music", ambience = "Ambience", dialog = "Dialog" }
local DEFAULTS = { enabled = true, alert = true, channel = "Master" }

local db, lastMessage, soundID

local function Print(msg)
    print(LOGO_ICON .. " |cffff66ccPI MLG|r " .. msg)
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
    return (msg.text:gsub("{player}", UnitName("player")))
end

-- Test banner (/pimlg test): a normal frame we fade ourselves

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

local function PlayMLG()
    PlaySoundFile(SOUND, db.channel)
    if not db.alert then return end
    local msg = PickMessage()
    testText:SetText(MessageText(msg))
    batchest:SetShown(msg.batchest == true)
    fade:Stop()
    batchest.flipbook:Restart()
    testBanner:Show()
    fade:Play()
end

-- PI banner: Blizzard's aura button shows while PI is on us, even in combat, but
-- addon scripts can't run on it. Everything is driven by the aura's timer instead:
-- the message is its duration text (blank and faded out after GONE_AT), and the
-- background is a stretched duration bar whose edge sweeps off during the fade.
-- The logo and animated batchest are clipped to that same edge.

local auraContainer, auraBanner

-- Inline icons are only a fallback for when the clipped art couldn't be created
local function BannerString(banner, msg)
    local s = MessageText(msg)
    if not banner.batchest then
        s = "|T" .. LOGO .. ":32:32|t  " .. s
        if msg.batchest then
            s = s .. "  |T" .. MEDIA .. "batchest:32:32:0:0:512:256:0:64:0:64|t" -- first flipbook frame
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

-- Clipped at the background's draining edge, so they wipe away with it
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

    -- The engine sets the text on registration, so the font must already be set
    banner.text = textHost:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    banner.text:SetPoint("TOPLEFT", banner.batchest and TEXT_INSET or 0, 0)
    banner.text:SetPoint("BOTTOMRIGHT")
    banner.text:SetTextColor(TEXT_R, TEXT_G, TEXT_B)
    banner.text:SetShadowOffset(2, -2)

    if not (pcall(CreateTextBinding, banner) and BindAuraText(banner)) then
        -- No engine text: static message for the whole PI window
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

    local slotOk, slot = pcall(container.AddAuraSlot, container, "pimlg", "HELPFUL", {
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

-- Sound: Blizzard plays aura sounds itself, so it works in combat.
-- Registering is blocked in combat, so we retry after combat.
local function RegisterSound()
    if soundID then pcall(C_UnitAuras.RemoveAuraSound, soundID) end
    soundID = nil
    if not db.enabled then return end
    local ok, id = pcall(C_UnitAuras.AddAuraSound, Enum.UnitAuraSoundTrigger.Added, {
        spellID = POWER_INFUSION, unitToken = "player", soundFileName = SOUND, outputChannel = db.channel,
    })
    if ok and type(id) == "number" then soundID = id end
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        if ... ~= ADDON then return end
        PowerInfusionMLGDB = PowerInfusionMLGDB or {}
        db = PowerInfusionMLGDB
        for k, v in pairs(DEFAULTS) do
            if db[k] == nil then db[k] = v end
        end
        self:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_ENTERING_WORLD" then
        RefreshAuraBanner()
        RegisterSound()
    elseif event == "PLAYER_REGEN_ENABLED" then
        if not soundID then RegisterSound() end
        if auraBanner and auraBanner.formatter then BindAuraText(auraBanner) end -- new message for next PI
    end
end)

-- Commands

local function Toggle(key, label)
    db[key] = not db[key]
    Print(label .. " " .. (db[key] and "on" or "off"))
    RefreshAuraBanner()
end

SLASH_POWERINFUSIONMLG1 = "/pimlg"
SlashCmdList.POWERINFUSIONMLG = function(msg)
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
    else
        Print("commands:")
        print("  /pimlg test - play the sound and alert")
        print("  /pimlg toggle - turn the addon on/off")
        print("  /pimlg alert - turn the on-screen alert on/off")
        print("  /pimlg master|sfx|music|ambience|dialog - volume channel")
    end
end

function PIMLG_OnCompartmentClick()
    PlayMLG()
end

function PIMLG_OnCompartmentEnter(_, button)
    GameTooltip:SetOwner(button, "ANCHOR_LEFT")
    GameTooltip:AddLine(LOGO_ICON .. " Power Infusion MLG")
    GameTooltip:AddLine(db.enabled and "|cff00ff00Enabled|r" or "|cffff0000Disabled|r")
    GameTooltip:AddLine("Click to test.", 1, 1, 1)
    GameTooltip:AddLine("/pimlg for commands", 0.7, 0.7, 0.7)
    GameTooltip:Show()
end

function PIMLG_OnCompartmentLeave()
    GameTooltip:Hide()
end
