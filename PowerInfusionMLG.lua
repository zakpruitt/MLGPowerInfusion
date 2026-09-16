local ADDON, ns = ...

local POWER_INFUSION = 10060
local MEDIA = "Interface\\AddOns\\PowerInfusionMLG\\Media\\"
local SOUND = MEDIA .. "mlg.mp3"
local LOGO = MEDIA .. "logo"
local LOGO_ICON = "|T" .. LOGO .. ":16:16|t"

local WIDTH, HEIGHT = 600, 64
local FADE_IN, HOLD, FADE_OUT = 0.15, 2.75, 0.6
local CHANNELS = { master = "Master", sfx = "SFX", music = "Music", ambience = "Ambience", dialog = "Dialog" }
local DEFAULTS = { enabled = true, alert = true, channel = "Master" }

local db
local lastMessage
local soundID

local function Print(msg)
    print(LOGO_ICON .. " |cffff66ccPI MLG|r " .. msg)
end

-- Banner

local function CreateBanner(parent, template)
    local banner = CreateFrame("Frame", nil, parent, template)
    banner:SetSize(WIDTH, HEIGHT)

    local bg = banner:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("TOPLEFT", -12, 6)
    bg:SetPoint("BOTTOMRIGHT", 12, -6)
    bg:SetColorTexture(0, 0, 0, 0.55)

    local logo = banner:CreateTexture(nil, "ARTWORK")
    logo:SetSize(56, 56)
    logo:SetPoint("LEFT", 4, 0)
    logo:SetTexture(LOGO)

    banner.batchest = banner:CreateTexture(nil, "ARTWORK")
    banner.batchest:SetSize(56, 56)
    banner.batchest:SetPoint("RIGHT", -4, 0)
    banner.batchest:SetTexture(MEDIA .. "batchest")

    banner.text = banner:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    banner.text:SetPoint("LEFT", logo, "RIGHT", 10, 0)
    banner.text:SetPoint("RIGHT", -70, 0)
    banner.text:SetTextColor(1, 0.85, 0.1)
    banner.text:SetShadowOffset(2, -2)

    banner.flipbook = banner.batchest:CreateAnimationGroup()
    banner.flipbook:SetLooping("REPEAT")
    local frames = banner.flipbook:CreateAnimation("FlipBook")
    frames:SetFlipBookRows(4)
    frames:SetFlipBookColumns(8)
    frames:SetFlipBookFrames(21)
    frames:SetDuration(21 * 0.04)

    -- Fade in, hold, fade out, and stay invisible until shown again
    local fade = banner:CreateAnimationGroup()
    fade:SetToFinalAlpha(true)
    local fadeIn = fade:CreateAnimation("Alpha")
    fadeIn:SetFromAlpha(0)
    fadeIn:SetToAlpha(1)
    fadeIn:SetDuration(FADE_IN)
    local fadeOut = fade:CreateAnimation("Alpha")
    fadeOut:SetFromAlpha(1)
    fadeOut:SetToAlpha(0)
    fadeOut:SetStartDelay(FADE_IN + HOLD)
    fadeOut:SetDuration(FADE_OUT)
    banner.fade = fade

    -- Runs whenever the banner becomes visible, including when Blizzard shows the aura button
    banner:SetScript("OnShow", function()
        pcall(banner.flipbook.Restart, banner.flipbook)
        pcall(fade.Restart, fade)
    end)
    return banner
end

local function SetMessage(banner)
    local messages = ns.messages
    local msg
    repeat
        msg = messages[math.random(#messages)]
    until msg ~= lastMessage or #messages < 2
    lastMessage = msg
    banner.text:SetText((msg.text:gsub("{player}", UnitName("player"))))
    banner.batchest:SetShown(msg.batchest == true)
end

-- Test banner: a normal frame we show ourselves for /pimlg test
local testBanner = CreateBanner(UIParent)
testBanner:SetPoint("TOP", 0, -140)
testBanner:SetFrameStrata("HIGH")
testBanner:Hide()
testBanner.fade:SetScript("OnFinished", function() testBanner:Hide() end)

local function PlayMLG()
    PlaySoundFile(SOUND, db.channel)
    if not db.alert then return end
    SetMessage(testBanner)
    testBanner:Hide()
    testBanner:Show()
end

-- PI banner: Blizzard shows an aura button while PI is on us, even in combat
-- where the aura is secret. Our banner is a child of that button, painted
-- before the button binds to the aura (after that it can't be touched).
local auraContainer, auraBanner

local function CreateAuraBanner()
    C_AddOns.LoadAddOn("Blizzard_AuraContainer")
    local ok, container = pcall(CreateFrame, "AuraContainer", nil, UIParent, "CustomAuraContainerTemplate")
    if not ok or not container then return end
    container:SetPoint("TOP", 0, -140)
    container:SetSize(WIDTH, HEIGHT)
    container:SetFrameStrata("HIGH")
    container:EnableMouse(false)

    local function Init(button)
        if auraBanner then return end
        button:EnableMouse(false)
        auraBanner = CreateBanner(button, "DisableUntrustedLayoutScriptsTemplate")
        auraBanner:SetPoint("CENTER", container)
        SetMessage(auraBanner)
    end

    local slotOk, slot = pcall(container.AddAuraSlot, container, "pimlg", "HELPFUL", {
        maxFrameCount = 1,
        initializeFrame = Init,
        candidateFilters = { includeSpellIDs = { [POWER_INFUSION] = true } },
        layout = { elementWidth = WIDTH, elementHeight = HEIGHT },
    })
    if not slotOk then return end
    if type(slot) == "table" and slot.SetPoint then Init(slot) end
    auraContainer = container
end

local function RefreshAuraBanner()
    if not auraContainer then CreateAuraBanner() end
    if not auraContainer then return end
    local on = db.enabled and db.alert
    pcall(auraContainer.SetEnabled, auraContainer, on)
    pcall(auraContainer.SetUnit, auraContainer, on and "player" or nil)
    if auraContainer.UpdateAllAuras then pcall(auraContainer.UpdateAllAuras, auraContainer) end
end

-- Sound: Blizzard plays aura sounds itself, so this works in combat too.
-- Registering is blocked in combat and encounters; we retry after combat.
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
        -- Fresh message for the next PI
        if auraBanner then pcall(SetMessage, auraBanner) end
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
