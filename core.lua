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
    selTier          = "raid", -- last shown category (persisted)
    selByTier        = {},     -- [tier] = last shown boss/dungeon/custom slot (persisted)
    charRaider       = {},     -- [characterName] = raiderName (assigned in-game, saved)
    backend          = "unit", -- "unit" (per-raider via raidN token) or "global" (no token;
                               -- one sound per spell; nonfunctional on 12.1, kept as a switch)
    globalSound      = nil,    -- fallback sound for the global backend
    mode             = "person", -- "person" (sound follows the raider) or "slot" (pinned to raidN)
    slotSound        = {},     -- [slotIndex] = sound value, used only in slot mode
    spellChannel     = {},     -- [entry] = output channel override (nil = main channel)
    spellPlayers     = {},     -- [entry] = { mode = "only"|"except"|nil, raiders = { [raider]=true } }
    spellSound       = {},     -- [entry] = SharedMedia sound name, played instead of the raider sound
    rules            = {},     -- rules[bossName] = { {channel=, mode="mute"|"only", windows={...}}, ... }
    rulesRestore     = {},     -- [cvar] = value to put back after a ruled encounter
    rulesLog         = true,   -- print channel changes made by rules
}

-- ---------------------------------------------------------------------------
-- Aura-sound API (12.1)
--   handle = C_UnitAuras.AddAuraSound(trigger, { spellID=, unitToken=, soundFileName= | soundKitID=, outputChannel= })
--   C_UnitAuras.RemoveAuraSound(handle)
-- Protected: can't be called in combat, while dead, or while restricted.
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

-- ---------------------------------------------------------------------------
-- Output channel + that channel's WoW volume CVar (mirrors the audio panel)
-- ---------------------------------------------------------------------------
local CHANNEL_VOL = {
    Master = "Sound_MasterVolume", SFX = "Sound_SFXVolume", Music = "Sound_MusicVolume",
    Ambience = "Sound_AmbienceVolume", Dialog = "Sound_DialogVolume",
}
function RAS:GetChannel() return (self.db and self.db.channel) or "Master" end
function RAS:SetChannel(c)
    if not CHANNEL_VOL[c] or c == self:GetChannel() then return end
    self.db.channel = c; self:Rebuild()   -- re-register through the new channel
end
function RAS:GetChannelVolume(ch)
    local cv = CHANNEL_VOL[ch or self:GetChannel()]
    return tonumber(cv and GetCVar(cv)) or 1
end
function RAS:SetChannelVolume(v)
    local cv = CHANNEL_VOL[self:GetChannel()]
    if cv then SetCVar(cv, tostring(math.max(0, math.min(1, v or 0)))) end
end
-- channel on/off switch CVars; Master's switch is the global "all sound" one
local CHANNEL_ON = {
    Master = "Sound_EnableAllSound", SFX = "Sound_EnableSFX", Music = "Sound_EnableMusic",
    Ambience = "Sound_EnableAmbience", Dialog = "Sound_EnableDialog",
}
-- folds in the master switch, since a channel is only audible when master is on
function RAS:GetChannelEnabled()
    local function on(cv) local v = GetCVar(cv); return v ~= nil and v ~= "0" end
    local c = self:GetChannel()
    return on("Sound_EnableAllSound") and (c == "Master" or on(CHANNEL_ON[c]))
end
function RAS:SetChannelEnabled(v)
    local cv = CHANNEL_ON[self:GetChannel()]
    if cv then SetCVar(cv, v and "1" or "0") end
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

-- ---------------------------------------------------------------------------
-- Spell sounds: a SharedMedia sound per spell entry, played instead of the
-- raider sound. Add the spell twice (one with a sound, one delayed) to hear
-- "<spell> <name>". Needs LibSharedMedia-3.0, loaded by any other addon.
-- ---------------------------------------------------------------------------
local function LSM() return LibStub and LibStub("LibSharedMedia-3.0", true) end

function RAS:SpellSoundList()
    local lsm = LSM(); if not lsm then return nil end
    local l = {}
    for _, nm in ipairs(lsm:List("sound")) do if nm ~= "None" then l[#l + 1] = nm end end
    return l
end

function RAS:SpellSoundPath(name)
    local lsm = LSM()
    return name and lsm and lsm:Fetch("sound", name, true) or nil
end

function RAS:PreviewSpellSound(name)
    local path = self:SpellSoundPath(name)
    if path then PlaySoundFile(path, self:GetChannel()) end
end

-- per-spell raider filter: "only" = just the listed raiders, "except" = everyone but them
function RAS:SpellAllows(spellID, raider)
    local sp = self.db.spellPlayers and self.db.spellPlayers[spellID]
    if not sp or not sp.mode then return true end
    local listed = raider ~= nil and sp.raiders and sp.raiders[raider] or false
    if sp.mode == "only" then return listed and true or false end
    return not listed
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

-- Spell entries: a group can hold the same spell more than once. The first is
-- keyed by the spellID (number), extra copies by "spellID:n" (string). All
-- per-spell settings (channel, players, sound, delay) are keyed by the entry.
local function entrySpell(key) return tonumber(key) or tonumber(tostring(key):match("^(%d+)")) end
RAS.EntrySpell = entrySpell
function RAS.EntryIndex(key) return tonumber(tostring(key):match(":(%d+)$")) or 1 end

-- a free entry key for spellID in group g (the plain ID if it isn't used yet)
function RAS:NewEntryKey(g, spellID)
    if g[spellID] == nil then return spellID end
    local n = 2
    while g[spellID .. ":" .. n] ~= nil do n = n + 1 end
    return spellID .. ":" .. n
end

-- per-entry output channel (set in the UI), else the main Output channel
local function spellChannel(key)
    local db = RAS.db
    return (db and db.spellChannel and db.spellChannel[key]) or (db and db.channel) or "Master"
end
RAS.SpellChannel = spellChannel

-- isFile: a number is a FileDataID (SharedMedia), not a sound kit
local function registerOne(spellID, token, sound, alsoRemoved, isFile, channel)
    if not AddAuraSound then return false end
    local opts = { spellID = spellID }
    if token then opts.unitToken = token end
    if type(sound) == "number" and not isFile then opts.soundKitID = sound
    else opts.soundFileName = sound end
    opts.outputChannel = channel or spellChannel(spellID)

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
    self.db.selByTier = self.db.selByTier or {}
    local items, sn, ok = self:GroupItems(st), self.db.selByTier[st], false
    for _, n in ipairs(items) do if n == sn then ok = true break end end
    if not ok then sn = items[1] or ""; self.db.selByTier[st] = sn end
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
    table.sort(l, RAS.EntryLess); return l
end

-- sort entries by spellID, then copy number (keys mix numbers and strings)
function RAS.EntryLess(a, b)
    local sa, sb = entrySpell(a), entrySpell(b)
    if sa ~= sb then return sa < sb end
    return RAS.EntryIndex(a) < RAS.EntryIndex(b)
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
    table.sort(l, RAS.EntryLess); return l
end
RAS.AllEnabledSpells = allEnabled

local function totalSpellCount(self)
    local n = 0
    for _, groups in pairs(self.db.groups or {}) do for _, spells in pairs(groups) do for _ in pairs(spells) do n = n + 1 end end end
    return n
end
RAS.TotalSpellCount = totalSpellCount

-- registration is blocked in combat, while dead, and while an addon restriction
-- is in force: combat, boss encounter, Mythic+, PvP match or a restricted map.
-- Tracked from ADDON_RESTRICTION_STATE_CHANGED (which fires as "Activating",
-- before it's enforced) and also asked directly, so it holds after a /reload.
local BLOCKING = { "Combat", "Encounter", "ChallengeMode", "PvPMatch", "Map" }
local _restrictions = {}   -- [type] = true from the event's Activating/Active until Inactive
local function blockingType(t)
    local T = Enum and Enum.AddOnRestrictionType
    if not T then return false end
    for _, k in ipairs(BLOCKING) do if T[k] ~= nil and T[k] == t then return true end end
    return false
end
local function restricted()
    if next(_restrictions) then return true end
    local CRA, T = C_RestrictedActions, Enum and Enum.AddOnRestrictionType
    if CRA and CRA.IsAddOnRestrictionActive and T then
        for _, k in ipairs(BLOCKING) do
            if T[k] ~= nil and CRA.IsAddOnRestrictionActive(T[k]) then return true end
        end
    end
    return false
end

local function canRegister()
    if InCombatLockdown() then return false end
    if UnitIsDeadOrGhost("player") then return false end
    if restricted() then return false end
    return true
end

function RAS:Rebuild()
    if not canRegister() then
        self.pendingRebuild = true
        if not self._retry then
            self._retry = true
            C_Timer.After(1, function() self._retry = nil; if self.pendingRebuild then RAS:Rebuild() end end)
        end
        return
    end
    self.pendingRebuild = nil

    self.lastCount, self.lastMissing = 0, 0
    if not self.db.enabled or not self:HasAPI() then
        clearRegistrations(); self._lastSig = nil
        if self.RefreshUI then self:RefreshUI() end
        return
    end

    local spells = allEnabled(self)
    if #spells == 0 then
        clearRegistrations(); self._lastSig = nil
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

    -- 1) build the DESIRED registration set (no API calls yet); s = entry key
    local desired, sigparts, missing = {}, {}, 0
    if self.db.backend == "global" then
        for _, s in ipairs(spells) do
            local base = (RAS.spellSounds and RAS.spellSounds[entrySpell(s)]) or self.db.globalSound
            local sound = self:ResolveSound(delayedSet[s] and delaySound(base) or base)
            if sound then
                desired[#desired + 1] = { s = entrySpell(s), token = nil, sound = sound, ch = spellChannel(s) }
                sigparts[#sigparts + 1] = s .. "|*|" .. tostring(sound) .. "|" .. spellChannel(s)
            else
                missing = missing + 1
            end
        end
    else
        local roster = self:BuildRoster()
        for token, name in pairs(roster) do
            local base
            if self.db.mode == "slot" then
                local i = tonumber(token:match("^raid(%d+)$")); base = i and self.db.slotSound[i]
            else
                base = self:CharSound(name)
            end
            if base then
                local raider = self:CharRaider(name)
                for _, s in ipairs(spells) do
                    if self:SpellAllows(s, raider) then
                        -- an entry with its own SharedMedia sound plays that INSTEAD of the raider sound
                        local own = self:SpellSoundPath(self.db.spellSound[s])
                        local sound = own or self:ResolveSound(delayedSet[s] and delaySound(base) or base)
                        if sound then
                            desired[#desired + 1] = { s = entrySpell(s), token = token, sound = sound, file = own ~= nil, ch = spellChannel(s) }
                            sigparts[#sigparts + 1] = s .. "|" .. token .. "|" .. tostring(sound) .. "|" .. spellChannel(s)
                        end
                    end
                end
            else
                missing = missing + 1   -- character present but not assigned to a raider
            end
        end
    end

    -- 2) skip if nothing changed since the last clean apply
    table.sort(sigparts)
    local sig = (self.db.channel or "Master") .. "#" .. table.concat(sigparts, ";")   -- channel change must re-register
    if sig == self._lastSig then
        self.lastMissing = missing
        if self.RefreshUI then self:RefreshUI() end
        return
    end

    -- 3) apply: clear old, register desired, note if anything was rejected (blocked)
    clearRegistrations()
    local count, blocked = 0, false
    for _, d in ipairs(desired) do
        if registerOne(d.s, d.token, d.sound, self.db.playRemoved, d.file, d.ch) then count = count + 1 else blocked = true end
    end
    -- only cache the signature on a clean apply, so a blocked attempt re-tries next time
    self._lastSig = blocked and nil or sig

    self.lastCount, self.lastMissing = count, missing
    if self.RefreshUI then self:RefreshUI() end
end

-- ---------------------------------------------------------------------------
-- Channel rules: per boss, mute a channel during windows ("mute") or keep it
-- off except during windows ("only"), or set its volume during windows
-- ("volume", rule.vol 0-1; lowest wins on overlap). A window is a fight-time range
-- { from=sec, to=sec|nil } or a boss-mod phase { stage=n } (from BigWigs/DBM),
-- optionally timed from the phase start { stage=n, from=sec, to=sec|nil }.
-- A rule can be limited to one difficulty (rule.diff = difficultyID).
-- Evaluated on a short ticker while a ruled encounter is active; the original
-- channel switches / volumes are saved and put back afterwards (also after a /reload).
-- ---------------------------------------------------------------------------
local enc   -- active ruled encounter: { boss, start, stage, rules, applied, ticker }

function RAS:BossForEncounter(id)
    for name, eid in pairs(RAS.encounterIDs or {}) do if eid == id then return name end end
end

local function rulesLog(msg) if RAS.db.rulesLog then print("|cff33ff99RAS rules|r " .. msg) end end
local function fmtClock(s) s = math.max(0, math.floor(s)); return ("%d:%02d"):format(math.floor(s / 60), s % 60) end
-- CVar values match (volumes may read back as "0.400000" for "0.4")
local function sameCV(a, b)
    if a == b then return true end
    local x, y = tonumber(a), tonumber(b)
    return x ~= nil and y ~= nil and math.abs(x - y) < 0.001
end

local function windowActive(w, t, stage, stageT)
    if w.stage then
        if stage ~= w.stage then return false end
        if not w.from then return true end
        t = stageT   -- timed window inside the phase
    end
    return t >= (w.from or 0) and (w.to == nil or t < w.to)
end

local function rulesEval()
    if not enc then return end
    local now = GetTime()
    local t, stageT = now - enc.start, now - enc.stageStart
    -- per channel: on if inside ANY "only" window (or there are no "only" rules),
    -- and off inside any "mute" window (mute wins)
    local hasOnly, inOnly, inMute = {}, {}, {}
    local volHas, volMin = {}, {}   -- volume CVars with a rule / lowest active volume
    for _, r in ipairs(enc.rules) do
        local cv = CHANNEL_ON[r.channel]
        if cv then
            local inside = false
            for _, w in ipairs(r.windows or {}) do if windowActive(w, t, enc.stage, stageT) then inside = true break end end
            if r.mode == "volume" then
                local vcv = CHANNEL_VOL[r.channel]
                volHas[vcv] = true
                if inside and r.vol then volMin[vcv] = math.min(volMin[vcv] or 1, r.vol) end
            elseif r.mode == "only" then
                hasOnly[cv] = true
                if inside then inOnly[cv] = true end
            else
                inMute[cv] = inMute[cv] or inside
            end
        end
    end
    -- volume: the rule's % inside a window, the saved normal volume outside
    for vcv in pairs(volHas) do
        local target = volMin[vcv] and tostring(volMin[vcv]) or RAS.db.rulesRestore[vcv]
        if target and enc.applied[vcv] ~= target then
            if not sameCV(GetCVar(vcv), target) then pcall(SetCVar, vcv, target) end
            if sameCV(GetCVar(vcv), target) then
                enc.applied[vcv] = target
                local nm = vcv:gsub("^Sound_", ""):gsub("Volume$", "")
                rulesLog(("%s volume %d%% @ %s (phase %s)"):format(nm, math.floor(tonumber(target) * 100 + 0.5), fmtClock(t), tostring(enc.stage)))
            end   -- if blocked, the next tick retries
        end
    end
    local want = {}
    for cv in pairs(hasOnly) do want[cv] = true end
    for cv in pairs(inMute) do want[cv] = true end
    for cv in pairs(want) do want[cv] = (not hasOnly[cv] or inOnly[cv] == true) and not inMute[cv] end
    for cv, on in pairs(want) do
        local v = on and "1" or "0"
        if enc.applied[cv] ~= v then
            if GetCVar(cv) ~= v then pcall(SetCVar, cv, v) end
            if GetCVar(cv) == v then
                enc.applied[cv] = v
                rulesLog(("%s %s @ %s (phase %s)"):format(cv:gsub("^Sound_Enable", ""), on and "|cff33ff99on|r" or "|cffff4040off|r", fmtClock(t), tostring(enc.stage)))
            end   -- if blocked, the next tick retries
        end
    end
end

function RAS:RulesRestore()
    if enc then return end
    local r = self.db and self.db.rulesRestore; if not r or not next(r) then return end
    for cv, val in pairs(r) do
        if not sameCV(GetCVar(cv), val) then pcall(SetCVar, cv, val) end
        if sameCV(GetCVar(cv), val) then r[cv] = nil end
    end
end

function RAS:RulesStart(encounterID, _, difficultyID)
    if enc then self:RulesEnd() end
    local boss = self:BossForEncounter(encounterID)
    -- only the rules for this difficulty (rule.diff = difficultyID, nil = all)
    local rules = {}
    for _, r in ipairs((boss and self.db.rules[boss]) or {}) do
        if not r.diff or r.diff == difficultyID then rules[#rules + 1] = r end
    end
    if #rules == 0 then return end
    enc = { boss = boss, start = GetTime(), stage = 1, rules = rules, applied = {} }
    enc.stageStart = enc.start
    -- remember the switches / volumes as they were (keep an older value if a restore is still pending)
    for _, r in ipairs(rules) do
        local cv = (r.mode == "volume" and CHANNEL_VOL or CHANNEL_ON)[r.channel]
        if cv and self.db.rulesRestore[cv] == nil then self.db.rulesRestore[cv] = GetCVar(cv) end
    end
    rulesLog(boss .. ": " .. #rules .. " rule(s) active" .. (self.phaseSource and (", phases via " .. self.phaseSource) or ", no boss mod for phases"))
    rulesEval()
    enc.ticker = C_Timer.NewTicker(0.2, rulesEval)
end

function RAS:RulesEnd()
    if not enc then return end
    if enc.ticker then enc.ticker:Cancel() end
    enc = nil
    self:RulesRestore()
end

function RAS:OnBossModStage(stage)
    stage = tonumber(stage)
    if enc and stage and stage ~= enc.stage then enc.stage = stage; enc.stageStart = GetTime(); rulesEval() end
end

-- follow BigWigs / DBM phase changes (their loaders are present at login)
function RAS:HookBossMods()
    if self._bmHooked then return end
    self._bmHooked = true
    if BigWigsLoader and BigWigsLoader.RegisterMessage then
        local ok = pcall(BigWigsLoader.RegisterMessage, RAS, "BigWigs_SetStage", function(_, _, stage) RAS:OnBossModStage(stage) end)
        if ok then self.phaseSource = "BigWigs" end
    end
    if DBM and DBM.RegisterCallback then
        local ok = pcall(DBM.RegisterCallback, DBM, "DBM_SetStage", function(_, _, _, stage) RAS:OnBossModStage(stage) end)
        if ok then self.phaseSource = self.phaseSource and (self.phaseSource .. " + DBM") or "DBM" end
    end
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
    if cmd == "rulelog" then RAS.db.rulesLog = not RAS.db.rulesLog; print("RAS rule log: " .. (RAS.db.rulesLog and "on" or "off"))
    elseif cmd == "addspell" then
        local id = tonumber(arg); local st, sn = RAS:Selected()
        if id then local g = RAS:GroupTable(st, sn, true); g[RAS:NewEntryKey(g, id)] = true; RAS:Rebuild(); if RAS.RefreshUI then RAS:RefreshUI() end; print("RAS: added spell " .. id .. " to " .. st .. "/" .. sn)
        else print("RAS: /has addspell <spellID>  (adds to the selected group)") end
    elseif cmd == "delspell" then
        local id = tonumber(arg); local st, sn = RAS:Selected(); local g = RAS:GroupTable(st, sn, false)
        if id and g then g[id] = nil; RAS:Rebuild(); if RAS.RefreshUI then RAS:RefreshUI() end; print("RAS: removed spell " .. id .. " from " .. st .. "/" .. sn)
        else print("RAS: /has delspell <spellID>  (removes from the selected group)") end
    elseif cmd == "spells" then
        local st, sn = RAS:Selected(); local t = RAS:GroupTracked(st, sn)
        print("|cff33ff99RAS spells|r " .. st .. "/" .. sn .. " (" .. #t .. "):")
        for _, s in ipairs(t) do
            local nm = (C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(entrySpell(s))) or "?"
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
    elseif cmd == "rebuild" or cmd == "apply" then RAS:Rebuild(); print("RAS: applied (" .. (RAS.lastCount or 0) .. " sound registrations)")
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
        print("|cff33ff99RAS|r  (blank = open UI) | addspell <id> | delspell <id> | spells | players | join <char> <raider> | roster | rulelog | channel <name> | backend unit/global | mode person/slot | rebuild | status | test <char> | combatsafe on/off")
    end
end

-- ---------------------------------------------------------------------------
-- Events
-- ---------------------------------------------------------------------------
-- Registration is combat-locked, so it happens in the out-of-combat moments
-- before a pull: zoning in, leaving combat, pull timer, ready check.
-- ---------------------------------------------------------------------------
-- 1s delay: runs outside the event handler (no taint), clears the combat-end
-- window, and collapses bursts of GROUP_ROSTER_UPDATE into one rebuild
function RAS:ScheduleRebuild()
    if self._scheduled then return end
    self._scheduled = true
    C_Timer.After(1, function() self._scheduled = nil; RAS:Rebuild() end)
end

f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
f:RegisterEvent("GROUP_ROSTER_UPDATE")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:RegisterEvent("PLAYER_UNGHOST")
f:RegisterEvent("PLAYER_ALIVE")
f:RegisterEvent("START_PLAYER_COUNTDOWN")
f:RegisterEvent("READY_CHECK")
f:RegisterEvent("ENCOUNTER_START")
f:RegisterEvent("ENCOUNTER_END")
if Enum and Enum.AddOnRestrictionType then f:RegisterEvent("ADDON_RESTRICTION_STATE_CHANGED") end

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
            -- migrate old single selName into per-tier selection memory
            if RAS_DB.selName and RAS_DB.selName ~= "" then
                RAS_DB.selByTier = RAS_DB.selByTier or {}
                local t = RAS_DB.selTier or "raid"
                if not RAS_DB.selByTier[t] then RAS_DB.selByTier[t] = RAS_DB.selName end
                RAS_DB.selName = nil
            end
        end

    elseif event == "PLAYER_LOGIN"
        or event == "PLAYER_ENTERING_WORLD"
        or event == "ZONE_CHANGED_NEW_AREA"
        or event == "GROUP_ROSTER_UPDATE"      -- roster shuffle changes token->raider
        or event == "PLAYER_REGEN_ENABLED"     -- left combat (e.g. after a wipe)
        or event == "PLAYER_UNGHOST" or event == "PLAYER_ALIVE"  -- resurrected / released
        or event == "START_PLAYER_COUNTDOWN"   -- pull timer: register right before the pull
        or event == "READY_CHECK" then         -- common pre-pull signal
        if event == "PLAYER_LOGIN" then RAS:HookBossMods() end
        RAS:RulesRestore()
        RAS:ScheduleRebuild()

    elseif event == "ENCOUNTER_START" then
        RAS:RulesStart(...)
    elseif event == "ENCOUNTER_END" then
        RAS:RulesEnd()

    elseif event == "ADDON_RESTRICTION_STATE_CHANGED" then
        local rType, rState = ...
        local S = Enum and Enum.AddOnRestrictionState
        if S and blockingType(rType) then
            if rState ~= S.Inactive then   -- Activating or Active
                _restrictions[rType] = true
            else
                _restrictions[rType] = nil
                RAS:RulesRestore()
                if not restricted() then
                    RAS:ScheduleRebuild()   -- flush anything deferred while restricted
                end
            end
        end
    end
end)