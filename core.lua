local ADDON, RAS = ...
RAS.folder = ADDON

-- parse RAS.roster ("Raider: char, char, ...") into lookups + character seed
RAS.playerSound, RAS.playerOrder, RAS.charSeed = {}, {}, {}
local function ras_trim(x) return x:match("^%s*(.-)%s*$") end
for _, line in ipairs(RAS.roster or {}) do
    local raider, chars = line:match("^([^:]*):?(.*)$")
    raider = ras_trim(raider or "")
    if raider ~= "" then
        if not RAS.playerSound[raider] then
            RAS.playerSound[raider] = raider:lower()
            RAS.playerOrder[#RAS.playerOrder + 1] = raider
        end
        for c in (chars or ""):gmatch("[^,]+") do
            c = ras_trim(c)
            if c ~= "" then RAS.charSeed[c] = raider end
        end
    end
end
table.sort(RAS.playerOrder)

local f = CreateFrame("Frame")
RAS.frame = f

-- ---------------------------------------------------------------------------
-- Saved defaults
-- ---------------------------------------------------------------------------
local defaults = {
    enabled          = true,   -- master on/off
    playRemoved      = false,  -- also fire on aura removal
    combatSafe       = false,  -- leave off: the API is combat-locked
    scale            = 1.0,    -- window scale (applied on slider release)
    channel          = "Master",
    groups           = {},     -- groups[tier][name] = { [spellID]=enabled }  (tier: raid/mplus/custom)
    gdelay           = {},     -- gdelay[tier][name] = { [spellID]=true }  spells using the delayed (d-prefixed) sound
    selTier          = "raid", -- currently shown category
    selName          = "",     -- currently shown boss/dungeon/custom slot
    charRaider       = {},     -- [characterName] = raiderName (assigned in-game, saved)
    backend          = "unit", -- "unit" (per-raider via raidN token) or "global" (no token;
                               -- one sound per spell; nonfunctional on 12.1, kept as a switch)
    globalSound      = nil,    -- fallback sound for the global backend
    mode             = "person", -- "person" (sound follows the raider) or "slot" (pinned to raidN)
    slotSound        = {},     -- [slotIndex] = sound value, used only in slot mode
}

-- ---------------------------------------------------------------------------
-- 12.1 sanctioned aura-sound registration API
-- ---------------------------------------------------------------------------
-- Signature discovered on the Midnight PTR (not documented):
--   handle = C_UnitAuras.AddAuraSound(trigger, sound)
--     trigger : Enum.UnitAuraSoundTrigger  (Added=0, ApplicationsIncreased=1, Removed=2)
--     sound   : { spellID=, unitToken=, soundFileName= | soundKitID= }
--   C_UnitAuras.RemoveAuraSound(handle)
--
-- THREE things this build assumes and the probe (/has probe) exists to prove:
--   1. AddAuraSound accepts raid1..raidN / partyN unit tokens (GAST only
--      confirmed player/target/focus/boss1-8; rejected plain names).
--   2. The remove function is named RemoveAuraSound.
--   3. Whether the API is combat-locked like the 12.0 private-aura sound APIs.
--      If the probe shows it is NOT combat-locked, flip /has combatsafe on and
--      registration will happen at ENCOUNTER_START so the FIRST pull has sound.
--      Left off by default, so first pull needs a pre-pull arm; re-pulls are
--      registered on leaving combat automatically.
-- ---------------------------------------------------------------------------
local CUA             = C_UnitAuras
local AddAuraSound    = CUA and CUA.AddAuraSound
local RemoveAuraSound = CUA and (CUA.RemoveAuraSound or CUA.RemoveAuraAppliedSound or CUA.RemovePrivateAuraAppliedSound)
local TriggerEnum     = Enum and Enum.UnitAuraSoundTrigger
local TRIGGER_ADDED   = (TriggerEnum and TriggerEnum.Added)   or 0
local TRIGGER_REMOVED = (TriggerEnum and TriggerEnum.Removed) or 2

function RAS:HasAPI()
    return type(AddAuraSound) == "function"
end

-- ---------------------------------------------------------------------------
-- Sound resolver
-- ---------------------------------------------------------------------------
local SOUND_DIR = "Interface\\AddOns\\" .. ADDON .. "\\Sounds\\"

function RAS:ResolveSound(value)
    if type(value) == "number" then return value end
    if type(value) ~= "string" then return nil end
    if value:sub(1, 5) == "file:" then
        return SOUND_DIR .. value:sub(6) .. ".ogg"
    end
    return value
end

-- the raider a character is assigned to: saved override first, else raiders.lua seed
function RAS:CharRaider(charName)
    if not charName then return nil end
    return (self.db.charRaider and self.db.charRaider[charName]) or (RAS.charSeed and RAS.charSeed[charName])
end

-- true if the character is defined in raiders.lua (charSeed) and so protected
function RAS:IsSeeded(charName)
    return charName ~= nil and RAS.charSeed ~= nil and RAS.charSeed[charName] ~= nil
end

-- resolve a character to its sound value ("file:<sound>") via its raider
function RAS:CharSound(charName)
    local raider = self:CharRaider(charName)
    local snd = raider and RAS.playerSound[raider]
    return snd and ("file:" .. snd) or nil
end

-- ---------------------------------------------------------------------------
-- Roster: live map of unit token -> character name
-- ---------------------------------------------------------------------------
function RAS:BuildRoster()
    local roster = {}
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local token = "raid" .. i
            if UnitExists(token) then
                local name = UnitName(token)
                if name then roster[token] = name end
            end
        end
    elseif IsInGroup() then
        roster["player"] = UnitName("player")
        for i = 1, GetNumGroupMembers() - 1 do
            local token = "party" .. i
            if UnitExists(token) then
                local name = UnitName(token)
                if name then roster[token] = name end
            end
        end
    else
        roster["player"] = UnitName("player")
    end
    return roster
end

-- ---------------------------------------------------------------------------
-- Registration
-- ---------------------------------------------------------------------------
local live = {}   -- list of active handles

local function clearRegistrations()
    if RemoveAuraSound then
        for i = #live, 1, -1 do
            pcall(RemoveAuraSound, live[i])
            live[i] = nil
        end
    else
        wipe(live)
    end
end
RAS.ClearRegistrations = clearRegistrations

local function registerOne(spellID, token, sound, alsoRemoved)
    if not AddAuraSound then return false end
    local opts = { spellID = spellID }
    if token then opts.unitToken = token end
    if type(sound) == "number" then opts.soundKitID = sound
    else opts.soundFileName = sound end
    opts.outputChannel = (RAS.db and RAS.db.channel) or "Master"

    local ok, handle = pcall(AddAuraSound, TRIGGER_ADDED, opts)
    if not (ok and handle) and opts.outputChannel then
        opts.outputChannel = nil   -- some clients may reject the field; keep the registration
        ok, handle = pcall(AddAuraSound, TRIGGER_ADDED, opts)
    end
    if ok and handle then
        live[#live + 1] = handle
        if alsoRemoved then
            local ok2, h2 = pcall(AddAuraSound, TRIGGER_REMOVED, opts)
            if ok2 and h2 then live[#live + 1] = h2 end
        end
        return true
    end
    return false, handle
end

-- register the global spell set plus an optional extra set against one token
local function registerSet(self, token, sound, globalSpells, extra)
    local n, seen = 0, {}
    for _, s in ipairs(globalSpells) do
        if not seen[s] then
            seen[s] = true
            if registerOne(s, token, sound, self.db.playRemoved) then n = n + 1 end
        end
    end
    if extra then
        for s in pairs(extra) do
            if not seen[s] then
                seen[s] = true
                if registerOne(s, token, sound, self.db.playRemoved) then n = n + 1 end
            end
        end
    end
    return n
end

-- ---------------------------------------------------------------------------
-- Spell groups (raid boss / mplus dungeon / custom slot)
-- ---------------------------------------------------------------------------
local function abbrev(name)
    local a = (name or ""):gsub("[^A-Z]", "")
    if a == "" then a = (name or ""):sub(1, 2):upper() end
    return a
end
RAS.Abbrev = abbrev

function RAS:GroupItems(tier)
    if tier == "raid" then return RAS.raid or {} end
    if tier == "mplus" then return RAS.mplus or {} end
    return { "1", "2", "3", "4", "5" }
end

-- resolve a valid current selection, fixing it if stale
function RAS:Selected()
    local st = self.db.selTier
    if st ~= "raid" and st ~= "mplus" and st ~= "custom" then st = "raid"; self.db.selTier = st end
    local items, sn, ok = self:GroupItems(st), self.db.selName, false
    for _, n in ipairs(items) do if n == sn then ok = true break end end
    if not ok then sn = items[1] or ""; self.db.selName = sn end
    return st, sn
end

function RAS:GroupTable(tier, name, create)
    local g = self.db.groups
    if not g[tier] then if create then g[tier] = {} else return nil end end
    if not g[tier][name] then if create then g[tier][name] = {} else return nil end end
    return g[tier][name]
end

function RAS:GroupTracked(tier, name)
    local t, l = self:GroupTable(tier, name, false), {}
    if t then for s in pairs(t) do l[#l + 1] = s end end
    table.sort(l); return l
end

-- does this group have at least one ENABLED (toggled-on) spell?
function RAS:GroupHasEnabled(tier, name)
    local t = self:GroupTable(tier, name, false)
    if t then for _, on in pairs(t) do if on then return true end end end
    return false
end

-- does any group in this tier have an enabled spell?
function RAS:TierHasEnabled(tier)
    for _, nm in ipairs(self:GroupItems(tier)) do if self:GroupHasEnabled(tier, nm) then return true end end
    return false
end

-- per-spell delayed flag (plays the d-prefixed sound file)
function RAS:GroupDelay(tier, name, create)
    local g = self.db.gdelay
    if not g[tier] then if create then g[tier] = {} else return nil end end
    if not g[tier][name] then if create then g[tier][name] = {} else return nil end end
    return g[tier][name]
end
function RAS:IsDelayed(tier, name, id)
    local g = self:GroupDelay(tier, name, false); return g and g[id] and true or false
end
function RAS:SetDelayed(tier, name, id, val)
    if val then self:GroupDelay(tier, name, true)[id] = true
    else local g = self:GroupDelay(tier, name, false); if g then g[id] = nil end end
end

-- union of enabled spells across ALL groups (everything registers regardless of
-- which group the UI is showing)
local function allEnabled(self)
    local seen, l = {}, {}
    for _, groups in pairs(self.db.groups or {}) do
        for _, spells in pairs(groups) do
            for s, on in pairs(spells) do if on and not seen[s] then seen[s] = true; l[#l + 1] = s end end
        end
    end
    table.sort(l); return l
end
RAS.AllEnabledSpells = allEnabled

local function totalSpellCount(self)
    local n = 0
    for _, groups in pairs(self.db.groups or {}) do for _, spells in pairs(groups) do for _ in pairs(spells) do n = n + 1 end end end
    return n
end
RAS.TotalSpellCount = totalSpellCount

function RAS:Rebuild()
    if InCombatLockdown() and not self.db.combatSafe then
        self.pendingRebuild = true
        return
    end
    self.pendingRebuild = nil
    clearRegistrations()

    self.lastCount, self.lastMissing = 0, 0
    if not self.db.enabled or not self:HasAPI() then
        if self.RefreshUI then self:RefreshUI() end
        return
    end

    local spells = allEnabled(self)
    if #spells == 0 then
        if self.RefreshUI then self:RefreshUI() end
        return
    end

    -- which spellIDs use the delayed (d-prefixed) sound? (delayed in any enabled group)
    local delayedSet = {}
    for tier, groups in pairs(self.db.groups or {}) do
        for name, sp in pairs(groups) do
            local gd = self.db.gdelay and self.db.gdelay[tier] and self.db.gdelay[tier][name]
            if gd then for s, on in pairs(sp) do if on and gd[s] then delayedSet[s] = true end end end
        end
    end
    local function delaySound(v)
        if type(v) == "string" and v:sub(1, 5) == "file:" then return "file:d" .. v:sub(6) end
        return v   -- can't d-prefix a raw path or numeric ID
    end

    local count, missing = 0, 0

    if self.db.backend == "global" then
        -- no unit token: one sound per spell (cannot know who got it)
        for _, s in ipairs(spells) do
            local base = (RAS.spellSounds and RAS.spellSounds[s]) or self.db.globalSound
            local sound = self:ResolveSound(delayedSet[s] and delaySound(base) or base)
            if sound then
                if registerOne(s, nil, sound, self.db.playRemoved) then count = count + 1 end
            else
                missing = missing + 1
            end
        end
    else
        -- unit backend: register every enabled spell against each character's sound
        local roster = self:BuildRoster()
        for token, name in pairs(roster) do
            local base
            if self.db.mode == "slot" then
                local i = tonumber(token:match("^raid(%d+)$")); base = i and self.db.slotSound[i]
            else
                base = self:CharSound(name)
            end
            if base then
                for _, s in ipairs(spells) do
                    local sound = self:ResolveSound(delayedSet[s] and delaySound(base) or base)
                    if sound and registerOne(s, token, sound, self.db.playRemoved) then count = count + 1 end
                end
            else
                missing = missing + 1   -- character present but not assigned to a raider
            end
        end
    end

    self.lastCount, self.lastMissing = count, missing
    if self.RefreshUI then self:RefreshUI() end
end

-- ---------------------------------------------------------------------------
-- Probe: the load-bearing feasibility test. Tries every registration shape the
-- sanctioned API might accept and reports which ones it takes. Run out of combat
-- in a real raid group. "accepted" only means the registration was taken; it
-- still needs the aura to actually apply to make a sound.
-- ---------------------------------------------------------------------------
local PROBE_SPELL = 1459                                -- Arcane Intellect, always exists
-- placeholder path: AddAuraSound does NOT validate the file at registration, so
-- this only tests token validity and is never actually played by the probe
local PROBE_SOUND = "Interface\\AddOns\\" .. ADDON .. "\\Sounds\\_probe.ogg"
function RAS:Probe()
    if not self:HasAPI() then
        print("|cffff4040RAS probe:|r C_UnitAuras.AddAuraSound missing. Need 12.1+.")
        return
    end
    if InCombatLockdown() then
        print("|cffff4040RAS probe:|r leave combat first.")
        return
    end

    local function try(labelStr, opts)
        local ok, handle = pcall(AddAuraSound, TRIGGER_ADDED, opts)
        if ok and handle then
            print("   " .. labelStr .. ": |cff33ff99accepted|r")
            if RemoveAuraSound then pcall(RemoveAuraSound, handle) end
        else
            print("   " .. labelStr .. ": |cffff4040rejected|r " .. tostring(handle))
        end
    end

    print("|cff33ff99RAS probe|r  spell=" .. PROBE_SPELL)

    -- unit-token shapes (these are what per-raider scoping needs)
    try("player token", { spellID = PROBE_SPELL, unitToken = "player", soundFileName = PROBE_SOUND })
    if IsInRaid() then
        local n = GetNumGroupMembers()
        try("raid1 token", { spellID = PROBE_SPELL, unitToken = "raid1", soundFileName = PROBE_SOUND })
        if n > 1 then
            try("raid" .. n .. " token", { spellID = PROBE_SPELL, unitToken = "raid" .. n, soundFileName = PROBE_SOUND })
        end
        local g = UnitGUID("raid1")
        if g then try("raid1 GUID as token", { spellID = PROBE_SPELL, unitToken = g, soundFileName = PROBE_SOUND }) end
        local nm = UnitName("raid1")
        if nm then try("raid1 name as token", { spellID = PROBE_SPELL, unitToken = nm, soundFileName = PROBE_SOUND }) end
    elseif IsInGroup() then
        try("party1 token", { spellID = PROBE_SPELL, unitToken = "party1", soundFileName = PROBE_SOUND })
    else
        print("   |cffd9b34c(not in a group - only 'player' tested; join a raid for the real test)|r")
    end
    if UnitExists("nameplate1") then
        try("nameplate1 token", { spellID = PROBE_SPELL, unitToken = "nameplate1", soundFileName = PROBE_SOUND })
    end

    -- fallback shapes
    try("no unitToken (global backend)", { spellID = PROBE_SPELL, soundFileName = PROBE_SOUND })
    try("player + soundKitID", { spellID = PROBE_SPELL, unitToken = "player", soundKitID = 8959 })

    print("|cff888888If raidN is rejected but 'no unitToken' is accepted, use /has backend global.|r")
end

-- ---------------------------------------------------------------------------
-- Local test playback (does a raider's file resolve and play on YOUR client?)
-- ---------------------------------------------------------------------------
function RAS:TestPlay(name)
    if not name or name == "" then print("RAS: /has test <CharacterName>") return end
    local sound = self:ResolveSound(self:CharSound(name))
    if not sound then print("|cffff4040RAS:|r '" .. name .. "' isn't assigned to a raider") return end
    if type(sound) == "number" then PlaySound(sound, self.db.channel)
    else PlaySoundFile(sound, self.db.channel) end
    print("RAS: played " .. name .. " (" .. tostring(self:CharRaider(name)) .. ")")
end

function RAS:PrintStatus()
    print("|cff33ff99Hex Aura Sounds|r")
    print("   API:      " .. (self:HasAPI() and "|cff33ff99present|r" or "|cffff4040missing (need 12.1)|r"))
    print("   enabled:  " .. tostring(self.db.enabled) .. "   channel: " .. (self.db.channel or "Master")
        .. "   playRemoved: " .. tostring(self.db.playRemoved))
    print("   spells: " .. #RAS.AllEnabledSpells(self) .. " enabled / " .. RAS.TotalSpellCount(self) .. " total")
    local players, seen = #RAS.playerOrder, {}
    for c, r in pairs(self.db.charRaider or {}) do if r then seen[c] = true end end
    for c in pairs(RAS.charSeed or {}) do seen[c] = true end
    local chars = 0; for _ in pairs(seen) do chars = chars + 1 end
    print("   raiders: " .. players .. "   characters assigned: " .. chars)
    print("   live regs: " .. (self.lastCount or 0)
        .. (self.lastMissing and self.lastMissing > 0 and ("   (" .. self.lastMissing .. " present, unassigned)") or ""))
end

-- ---------------------------------------------------------------------------
-- Slash
-- ---------------------------------------------------------------------------
SLASH_RAS1 = "/has"
SlashCmdList.RAS = function(msg)
    msg = (msg or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local cmd, arg = msg:match("^(%S*)%s*(.-)$")
    cmd = (cmd or ""):lower()
    if cmd == "probe"     then RAS:Probe()
    elseif cmd == "testfire" then
        local a1, a2, a3 = arg:match("^(%S+)%s*(%S*)%s*(%S*)$")
        local sound = a1 and RAS:ResolveSound(a1)
        local spellID = tonumber(a2) or 1459
        local token = (a3 ~= "" and a3) or "player"
        if not sound then
            print("RAS: /has testfire <file:Name | path> [spellID] [unitToken]   e.g. /has testfire file:breath 1459 raid6")
        elseif not RAS:HasAPI() then
            print("|cffff4040RAS:|r API missing")
        elseif InCombatLockdown() then
            print("|cffff4040RAS:|r out of combat only")
        elseif not UnitExists(token) then
            print("|cffff4040RAS:|r no unit at '" .. token .. "'")
        else
            local opts = { spellID = spellID, unitToken = token }
            if type(sound) == "number" then opts.soundKitID = sound else opts.soundFileName = sound end
            opts.outputChannel = RAS.db.channel or "Master"
            local ok, h = pcall(C_UnitAuras.AddAuraSound, (Enum and Enum.UnitAuraSoundTrigger and Enum.UnitAuraSoundTrigger.Added) or 0, opts)
            if ok and h then
                print("RAS testfire: " .. token .. " (" .. (UnitName(token) or "?") .. ") + spell " .. spellID
                    .. " -> " .. tostring(sound) .. ". Apply that aura to them to hear it. Auto-clears in 25s.")
                C_Timer.After(25, function()
                    if C_UnitAuras.RemoveAuraSound then pcall(C_UnitAuras.RemoveAuraSound, h) end
                    print("RAS testfire: cleared")
                end)
            else
                print("|cffff4040RAS testfire rejected:|r " .. tostring(h))
            end
        end
    elseif cmd == "addspell" then
        local id = tonumber(arg); local st, sn = RAS:Selected()
        if id then RAS:GroupTable(st, sn, true)[id] = true; RAS:Rebuild(); if RAS.RefreshUI then RAS:RefreshUI() end; print("RAS: added spell " .. id .. " to " .. st .. "/" .. sn)
        else print("RAS: /has addspell <spellID>  (adds to the selected group)") end
    elseif cmd == "delspell" then
        local id = tonumber(arg); local st, sn = RAS:Selected(); local g = RAS:GroupTable(st, sn, false)
        if id and g then g[id] = nil; RAS:Rebuild(); if RAS.RefreshUI then RAS:RefreshUI() end; print("RAS: removed spell " .. id .. " from " .. st .. "/" .. sn)
        else print("RAS: /has delspell <spellID>  (removes from the selected group)") end
    elseif cmd == "spells" then
        local st, sn = RAS:Selected(); local t = RAS:GroupTracked(st, sn)
        print("|cff33ff99RAS spells|r " .. st .. "/" .. sn .. " (" .. #t .. "):")
        for _, s in ipairs(t) do
            local nm = (C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(s)) or "?"
            print("   " .. s .. "  " .. nm)
        end
    elseif cmd == "join" then
        local nm, raider = arg:match("^(%S+)%s+(.+)$")
        if nm and raider and RAS.playerSound[raider] then
            RAS.db.charRaider[nm] = raider; RAS:Rebuild()
            if RAS.RefreshUI then RAS:RefreshUI() end
            print("RAS: " .. nm .. " -> " .. raider)
        elseif nm and raider then
            print("RAS: '" .. raider .. "' isn't a raider. See /has players")
        else print("RAS: /has join <CharacterName> <Raider>   e.g. /has join Grimgripper Toobad") end
    elseif cmd == "players" then
        print("|cff33ff99RAS raiders|r (" .. #RAS.playerOrder .. "):")
        for _, nm in ipairs(RAS.playerOrder) do print("   " .. nm .. "  |cff888888" .. RAS.playerSound[nm] .. "|r") end
    elseif cmd == "rebuild" then RAS:Rebuild(); print("RAS: rebuilt (" .. (RAS.lastCount or 0) .. " regs)")
    elseif cmd == "status" then RAS:PrintStatus()
    elseif cmd == "test"  then RAS:TestPlay(arg)
    elseif cmd == "toggle" then RAS.db.enabled = not RAS.db.enabled; RAS:Rebuild(); print("RAS enabled: " .. tostring(RAS.db.enabled))
    elseif cmd == "roster" then
        local roster = RAS:BuildRoster()
        local order = {}
        for t in pairs(roster) do order[#order + 1] = t end
        table.sort(order, function(a, b)
            local na = tonumber(a:match("%d+")) or 0
            local nb = tonumber(b:match("%d+")) or 0
            if (a:match("%a+")) == (b:match("%a+")) then return na < nb end
            return a < b
        end)
        print("|cff33ff99RAS roster|r (" .. #order .. " units):")
        for _, t in ipairs(order) do
            local name = roster[t]
            local snd = RAS:ResolveSound(RAS:CharSound(name))
            local grp = ""
            local idx = tonumber(t:match("^raid(%d+)$"))
            if idx then
                local _, _, subgroup = GetRaidRosterInfo(idx)
                if subgroup then grp = "  |cff888888grp " .. subgroup .. "|r" end
            end
            print("   " .. t .. " = " .. name .. grp .. (snd and ("  |cff4cd972" .. (RAS:CharRaider(name) or "") .. "|r") or "  |cffd95252[unassigned]|r"))
        end
    elseif cmd == "channel" then
        local c = arg:gsub("^%l", string.upper)
        local valid = { Master = true, SFX = true, Music = true, Ambience = true, Dialog = true }
        if valid[c] then RAS.db.channel = c; RAS:Rebuild(); print("RAS channel: " .. c)
        elseif arg == "" then print("RAS channel is '" .. (RAS.db.channel or "Master") .. "'  (Master|SFX|Music|Ambience|Dialog)")
        else print("RAS: unknown channel '" .. arg .. "'  (Master|SFX|Music|Ambience|Dialog)") end
    elseif cmd == "combatsafe" then
        RAS.db.combatSafe = (arg:lower() == "on")
        print("RAS combatSafe: " .. tostring(RAS.db.combatSafe))
    elseif cmd == "api" then
        print("|cff33ff99RAS|r C_UnitAuras sound functions:")
        local any = false
        for k in pairs(C_UnitAuras or {}) do
            if type(k) == "string" and k:lower():find("sound") then print("   " .. k); any = true end
        end
        if not any then print("   (none found)") end
        print("   remove resolved: " .. (RemoveAuraSound and "|cff33ff99yes|r" or "|cffff4040NO - rebuilds will stack!|r"))
    elseif cmd == "backend" then
        local b = arg:lower()
        if b == "unit" or b == "global" then
            RAS.db.backend = b; RAS:Rebuild()
            if RAS.RefreshUI then RAS:RefreshUI() end
            print("RAS backend: " .. b)
        else
            print("RAS backend is '" .. (RAS.db.backend or "unit") .. "'  (use /has backend unit|global)")
        end
    elseif cmd == "globalsound" then
        RAS.db.globalSound = (arg ~= "" and arg) or RAS.db.globalSound
        RAS:Rebuild()
        print("RAS globalSound: " .. tostring(RAS.db.globalSound))
    elseif cmd == "mode" then
        local m = arg:lower()
        if m == "slot" or m == "person" then
            RAS.db.mode = m; RAS:Rebuild()
            if RAS.RefreshUI then RAS:RefreshUI() end
            print("RAS mode: " .. m)
        else
            print("RAS mode is '" .. (RAS.db.mode or "person") .. "'  (use /has mode person|slot)")
        end
    elseif cmd == "fillslots" then
        if IsInRaid() then
            local n = 0
            for i = 1, GetNumGroupMembers() do
                local nm = UnitName("raid" .. i)
                if nm and RAS:CharSound(nm) then RAS.db.slotSound[i] = RAS:CharSound(nm); n = n + 1 end
            end
            RAS:Rebuild()
            if RAS.RefreshUI then RAS:RefreshUI() end
            print("RAS: stamped " .. n .. " slot sound(s) from the current roster")
        else
            print("RAS: join a raid first")
        end
    elseif cmd == "who" then
        if UnitExists("mouseover") then
            local slot = UnitInRaid("mouseover")
            print("RAS mouseover: " .. (UnitName("mouseover") or "?") .. "   raidSlot=" .. tostring(slot or "-"))
        else
            print("RAS: nothing under the cursor")
        end
    elseif cmd == "" or cmd == "config" or cmd == "show" then
        if RAS.Toggle then RAS:Toggle() else RAS:PrintStatus() end
    else
        print("|cff33ff99RAS|r  (blank = open UI) | addspell <id> | delspell <id> | spells | players | join <char> <raider> | roster | probe | testfire <file:Name> [spellID] [unit] | api | channel <name> | backend unit/global | mode person/slot | rebuild | status | test <char> | combatsafe on/off")
    end
end

-- ---------------------------------------------------------------------------
-- Events
-- ---------------------------------------------------------------------------
-- Registration is combat-locked and ENCOUNTER_START fires with combat already
-- up, so we never register there. Instead we register during the out-of-combat
-- windows that always precede a pull: zoning in, leaving combat (after a wipe),
-- a pull countdown, and a ready check. Spells are a flat global list, so once
-- registered they cover whatever gets pulled; the first pull is covered by the
-- zone-in / ready-check registration.
-- ---------------------------------------------------------------------------
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
f:RegisterEvent("GROUP_ROSTER_UPDATE")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:RegisterEvent("START_PLAYER_COUNTDOWN")
f:RegisterEvent("READY_CHECK")

f:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        if ... == ADDON then
            RAS_DB = RAS_DB or {}
            for k, v in pairs(defaults) do
                if RAS_DB[k] == nil then
                    RAS_DB[k] = (type(v) == "table") and {} or v
                end
            end
            RAS.db = RAS_DB
            -- migrate old flat spell list (pre-groups) into Custom slot 1
            if RAS_DB.spells and next(RAS_DB.spells) and not next(RAS_DB.groups) then
                RAS_DB.groups.custom = RAS_DB.groups.custom or {}
                RAS_DB.groups.custom["1"] = RAS_DB.groups.custom["1"] or {}
                for id, on in pairs(RAS_DB.spells) do RAS_DB.groups.custom["1"][id] = on end
                RAS_DB.spells = nil
            end
        end

    elseif event == "PLAYER_LOGIN"
        or event == "PLAYER_ENTERING_WORLD"
        or event == "ZONE_CHANGED_NEW_AREA"
        or event == "GROUP_ROSTER_UPDATE"      -- roster shuffle changes token->raider
        or event == "PLAYER_REGEN_ENABLED"     -- left combat (e.g. after a wipe)
        or event == "START_PLAYER_COUNTDOWN"   -- pull timer: register right before the pull
        or event == "READY_CHECK" then         -- common pre-pull signal
        RAS:Rebuild()
    end
end)