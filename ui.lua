local ADDON, RAS = ...

local FONT    = "Interface\\AddOns\\HexAuraSounds\\fonts\\expressway.ttf"
local SPEAKER = "Interface\\AddOns\\HexAuraSounds\\media\\speaker.tga"
local ARROW   = "Interface\\AddOns\\HexAuraSounds\\media\\down_arrow.tga"

local GOLD  = {0.80, 0.66, 0.30}
local TEXT  = {0.86, 0.87, 0.89}
local MUTED = {0.42, 0.45, 0.50}
local HAIR  = {0.16, 0.17, 0.20}
local PANEL = {0.075, 0.082, 0.095}
local GREEN = {0.30, 0.80, 0.46}
local RED   = {0.85, 0.34, 0.31}

local function bg(f, r, g, b, a)
    local t = f:CreateTexture(nil, "BACKGROUND"); t:SetAllPoints(); t:SetColorTexture(r, g, b, a or 1); f.bg = t; return t
end
local function stroke(f, c, s)
    c, s = c or HAIR, s or 1
    local function edge(p1, p2, w, h)
        local t = f:CreateTexture(nil, "BORDER"); t:SetColorTexture(c[1], c[2], c[3], c[4] or 1)
        t:SetPoint(p1); t:SetPoint(p2); if w then t:SetWidth(w) end; if h then t:SetHeight(h) end
    end
    edge("TOPLEFT", "TOPRIGHT", nil, s); edge("BOTTOMLEFT", "BOTTOMRIGHT", nil, s)
    edge("TOPLEFT", "BOTTOMLEFT", s, nil); edge("TOPRIGHT", "BOTTOMRIGHT", s, nil)
end
local function fs(parent, size, col, flags)
    local t = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    local dp = t:GetFont(); if not t:SetFont(FONT, size or 12, flags or "") then t:SetFont(dp, size or 12, flags or "") end
    col = col or TEXT; t:SetTextColor(col[1], col[2], col[3]); return t
end
local function softButton(parent, text, w, h, onClick, col)
    local b = CreateFrame("Button", nil, parent); b:SetSize(w, h); b:RegisterForClicks("LeftButtonDown")
    local hl = b:CreateTexture(nil, "BACKGROUND"); hl:SetAllPoints(); hl:SetColorTexture(1, 1, 1, 0)
    b.t = fs(b, 12, col or GOLD); b.t:SetPoint("CENTER"); b.t:SetText(text)
    b:SetScript("OnEnter", function() hl:SetColorTexture(1, 1, 1, 0.06); b.t:SetTextColor(1, 1, 1) end)
    b:SetScript("OnLeave", function() hl:SetColorTexture(1, 1, 1, 0); local c = col or GOLD; b.t:SetTextColor(c[1], c[2], c[3]) end)
    b:SetScript("OnClick", onClick); return b
end
local function iconButton(parent, tex, size, onClick)
    local b = CreateFrame("Button", nil, parent); b:SetSize(size, size); b:RegisterForClicks("LeftButtonDown")
    local t = b:CreateTexture(nil, "ARTWORK"); t:SetAllPoints(); t:SetTexture(tex)
    t:SetVertexColor(0.72, 0.75, 0.80); b.tex = t
    b:SetScript("OnEnter", function() t:SetVertexColor(1, 1, 1) end)
    b:SetScript("OnLeave", function() t:SetVertexColor(0.72, 0.75, 0.80) end)
    b:SetScript("OnClick", onClick); return b
end
local function makeEdit(parent, w, placeholder, onCommit)
    local e = CreateFrame("EditBox", nil, parent); e:SetSize(w, 20); e:SetAutoFocus(false); e:SetFontObject("GameFontHighlightSmall")
    local dp = e:GetFont(); if not e:SetFont(FONT, 12, "") then e:SetFont(dp, 12, "") end
    e:SetTextInsets(7, 7, 0, 0); e:SetTextColor(0.9, 0.9, 0.92); bg(e, 0.095, 0.105, 0.12); stroke(e, HAIR, 1)
    e.ph = fs(e, 12, MUTED); e.ph:SetPoint("LEFT", 8, 0); e.ph:SetText(placeholder or "")
    local function upd() e.ph:SetShown(e:GetText() == "" and not e:HasFocus()) end
    e:SetScript("OnTextChanged", upd); e:SetScript("OnEditFocusGained", upd); e:SetScript("OnEditFocusLost", upd)
    e:SetScript("OnEscapePressed", function() e:ClearFocus() end)
    e:SetScript("OnEnterPressed", function() if onCommit then onCommit(e:GetText()) end e:ClearFocus() end)
    upd(); return e
end
local function makeSwitch(parent, get, set, w, h)
    local s = CreateFrame("Button", nil, parent); w, h = w or 34, h or 16; s:SetSize(w, h); s:RegisterForClicks("LeftButtonDown")
    s.track = s:CreateTexture(nil, "BACKGROUND"); s.track:SetAllPoints(); stroke(s, HAIR, 1)
    s.knob = s:CreateTexture(nil, "OVERLAY"); s.knob:SetSize(h - 4, h - 4)
    function s:refresh()
        local on = get() and true or false
        if on then self.track:SetColorTexture(GREEN[1], GREEN[2], GREEN[3], 0.9) else self.track:SetColorTexture(0.16, 0.17, 0.19, 1) end
        self.knob:SetColorTexture(0.93, 0.93, 0.95, 1); self.knob:ClearAllPoints(); self.knob:SetPoint(on and "RIGHT" or "LEFT", on and -2 or 2, 0)
    end
    s:SetScript("OnClick", function() set(not get()); s:refresh() end); return s
end
-- compact vertical toggle (fills green when on, grey when off)
local function vToggle(parent, w, h, get, set)
    local b = CreateFrame("Button", nil, parent); b:SetSize(w, h); b:RegisterForClicks("LeftButtonDown")
    bg(b, 0.14, 0.15, 0.17, 1); stroke(b, HAIR, 1)
    b.fill = b:CreateTexture(nil, "ARTWORK"); b.fill:SetPoint("TOPLEFT", 1, -1); b.fill:SetPoint("BOTTOMRIGHT", -1, 1)
    function b:refresh()
        if get() then b.fill:SetColorTexture(GREEN[1], GREEN[2], GREEN[3], 0.9) else b.fill:SetColorTexture(0.30, 0.31, 0.34, 0.5) end
    end
    b:SetScript("OnClick", function() set(not get()); b:refresh() end); return b
end
local function makeMiniSlider(parent, opts)
    local INSET = 2; local TW = opts.thumbW or 40; local minV, maxV, step = opts.min, opts.max, opts.step
    local s = CreateFrame("Frame", nil, parent); s:SetSize(opts.width or 110, opts.height or 18)
    bg(s, 0.05, 0.055, 0.065, 1); stroke(s, HAIR, 1); s:EnableMouse(true)
    local thumb = CreateFrame("Frame", nil, s); bg(thumb, 0.22, 0.23, 0.26, 1); stroke(thumb, {0.42, 0.44, 0.48}, 1); thumb:EnableMouse(false)
    local text = fs(thumb, 11, TEXT); text:SetPoint("CENTER")
    s._value = opts.get and opts.get() or minV
    local function clampStep(v) v = minV + math.floor((v - minV) / step + 0.5) * step; return math.max(minV, math.min(maxV, v)) end
    local function refresh()
        local w = s:GetWidth() or 0; local travel = math.max(0, w - 2 * INSET - TW)
        local frac = (maxV > minV) and (s._value - minV) / (maxV - minV) or 0
        thumb:SetSize(TW, (s:GetHeight() or 18) - 2 * INSET); thumb:ClearAllPoints(); thumb:SetPoint("TOPLEFT", s, "TOPLEFT", INSET + travel * frac, -INSET)
        text:SetText(opts.format and opts.format(s._value) or tostring(s._value))
    end
    local function valueFromCursor()
        local left = s:GetLeft(); if not left then return s._value end
        local x = GetCursorPosition() / s:GetEffectiveScale(); local w = s:GetWidth(); if not w or w <= 0 then w = 1 end
        local travel = math.max(1, w - 2 * INSET - TW); local frac = (x - left - INSET - TW / 2) / travel
        return clampStep(minV + math.max(0, math.min(1, frac)) * (maxV - minV))
    end
    local dragging = false
    s:SetScript("OnMouseDown", function(self2, btn)
        if btn ~= "LeftButton" then return end
        dragging = true; s._value = valueFromCursor(); refresh(); if opts.onChange then opts.onChange(s._value, false) end
        self2:SetScript("OnUpdate", function() s._value = valueFromCursor(); refresh(); if opts.onChange then opts.onChange(s._value, false) end end)
    end)
    s:SetScript("OnMouseUp", function(self2) if not dragging then return end dragging = false; self2:SetScript("OnUpdate", nil); if opts.onChange then opts.onChange(s._value, true) end end)
    s:SetScript("OnSizeChanged", refresh); s.refresh = refresh
    function s:SyncValue() if opts.get then s._value = opts.get() end refresh() end
    refresh(); return s
end
local function makeIcon(parent, size)
    local h = CreateFrame("Frame", nil, parent); h:SetSize(size, size); bg(h, 0, 0, 0, 1); stroke(h, HAIR, 1)
    local t = h:CreateTexture(nil, "ARTWORK"); t:SetPoint("TOPLEFT", 1, -1); t:SetPoint("BOTTOMRIGHT", -1, 1); t:SetTexCoord(0.08, 0.92, 0.08, 0.92); h.tex = t; return h
end
local function trunc(s, n) if not s then return "" end if #s > n then return s:sub(1, n) .. "..." end return s end
local function soundLabel(v)
    if v == nil then return nil end
    if type(v) == "number" then return "kit:" .. v end
    if v:sub(1, 5) == "file:" then return v:sub(6) end
    return v:match("[^\\/]+$") or v
end

-- single-column scroll list (used by the picker) --------------------------------
local function scroll(parent, w, h, rowH, create, update)
    local BAR = 6; local sf = CreateFrame("Frame", nil, parent); sf:SetSize(w, h)
    bg(sf, PANEL[1], PANEL[2], PANEL[3], 1); stroke(sf, HAIR, 1); sf.rows, sf.offset, sf.data = {}, 0, {}
    local visible = math.max(1, math.floor((h - 4) / rowH))
    for i = 1, visible do
        local row = create(sf); row:SetSize(w - 6 - BAR, rowH); row:SetPoint("TOPLEFT", 2, -((i - 1) * rowH) - 2)
        row.hl = row:CreateTexture(nil, "BACKGROUND"); row.hl:SetAllPoints(); row.hl:SetColorTexture(1, 1, 1, 0); sf.rows[i] = row
    end
    local track = CreateFrame("Frame", nil, sf); track:SetPoint("TOPRIGHT", -2, -2); track:SetPoint("BOTTOMRIGHT", -2, 2); track:SetWidth(BAR)
    local tt = track:CreateTexture(nil, "BACKGROUND"); tt:SetAllPoints(); tt:SetColorTexture(1, 1, 1, 0.04)
    local thumb = CreateFrame("Frame", nil, track); thumb:SetPoint("TOP", 0, 0); thumb:SetSize(BAR, 24); thumb:EnableMouse(true)
    local tx = thumb:CreateTexture(nil, "ARTWORK"); tx:SetAllPoints()
    local function tcol(a) tx:SetColorTexture(0.52, 0.55, 0.60, a) end
    tcol(0.55); thumb:SetScript("OnEnter", function() tcol(0.85) end); thumb:SetScript("OnLeave", function() if not sf.dragging then tcol(0.55) end end)
    thumb:SetScript("OnMouseDown", function(self2)
        sf.dragging = true; local _, cy = GetCursorPosition(); sf.dc, sf.doff = cy, sf.offset
        self2:SetScript("OnUpdate", function()
            local n = #sf.data; local maxOff = math.max(0, n - visible); local range = track:GetHeight() - thumb:GetHeight()
            local _, ny = GetCursorPosition(); local moved = (sf.dc - ny) / sf:GetEffectiveScale()
            if range > 0 and maxOff > 0 then sf.offset = math.min(maxOff, math.max(0, math.floor(sf.doff + (moved / range) * maxOff + 0.5))); sf:Refresh() end
        end)
    end)
    thumb:SetScript("OnMouseUp", function(self2) sf.dragging = false; self2:SetScript("OnUpdate", nil); tcol(0.55) end)
    function sf:Refresh()
        local n = #self.data; local maxOff = math.max(0, n - visible); if self.offset > maxOff then self.offset = maxOff end
        for i, row in ipairs(self.rows) do local d = self.data[i + self.offset]; if d then row.data = d; update(row, d); row:Show() else row.data = nil; row:Hide() end end
        local th = track:GetHeight()
        if n > visible and th > 0 then local thumbH = math.max(18, th * visible / n); local range = th - thumbH; thumb:SetHeight(thumbH); thumb:ClearAllPoints(); thumb:SetPoint("TOP", 0, -(maxOff > 0 and (self.offset / maxOff) or 0) * range); track:Show() else track:Hide() end
    end
    function sf:SetData(list) self.data = list or {}; self:Refresh() end
    sf:EnableMouseWheel(true); sf:SetScript("OnMouseWheel", function(self2, delta) self2.offset = math.max(0, self2.offset - delta); self2:Refresh() end)
    return sf
end

-- multi-column grid: fills left-to-right then down, scrolls by rows --------------
local function gridScroll(parent, w, h, cols, cellH, create, update)
    local BAR = 6; local sf = CreateFrame("Frame", nil, parent); sf:SetSize(w, h)
    bg(sf, PANEL[1], PANEL[2], PANEL[3], 1); stroke(sf, HAIR, 1)
    local cellW = math.floor((w - 4 - BAR) / cols); local rowsVis = math.max(1, math.floor((h - 4) / cellH))
    sf.cells, sf.offset, sf.data, sf.cellW = {}, 0, {}, cellW
    for i = 0, cols * rowsVis - 1 do
        local col = i % cols; local row = math.floor(i / cols)
        local cell = create(sf); cell:SetSize(cellW, cellH); cell:SetPoint("TOPLEFT", 2 + col * cellW, -(row * cellH) - 2)
        cell.zebra = cell:CreateTexture(nil, "BACKGROUND"); cell.zebra:SetAllPoints(); cell.zebra:SetColorTexture(1, 1, 1, 0.025); cell.zebra:Hide()
        cell.hl = cell:CreateTexture(nil, "BACKGROUND"); cell.hl:SetAllPoints(); cell.hl:SetColorTexture(1, 1, 1, 0)
        sf.cells[i + 1] = cell
    end
    for c = 1, cols - 1 do
        local ln = sf:CreateTexture(nil, "ARTWORK"); ln:SetColorTexture(HAIR[1], HAIR[2], HAIR[3], 1); ln:SetWidth(1)
        ln:SetPoint("TOPLEFT", 2 + c * cellW, -2); ln:SetPoint("BOTTOMLEFT", 2 + c * cellW, 2)
    end
    local track = CreateFrame("Frame", nil, sf); track:SetPoint("TOPRIGHT", -2, -2); track:SetPoint("BOTTOMRIGHT", -2, 2); track:SetWidth(BAR)
    local tt = track:CreateTexture(nil, "BACKGROUND"); tt:SetAllPoints(); tt:SetColorTexture(1, 1, 1, 0.04)
    local thumb = CreateFrame("Frame", nil, track); thumb:SetPoint("TOP", 0, 0); thumb:SetSize(BAR, 24); thumb:EnableMouse(true)
    local tx = thumb:CreateTexture(nil, "ARTWORK"); tx:SetAllPoints()
    local function tcol(a) tx:SetColorTexture(0.52, 0.55, 0.60, a) end
    tcol(0.55)
    local function totalRows() return math.ceil(#sf.data / cols) end
    thumb:SetScript("OnEnter", function() tcol(0.85) end); thumb:SetScript("OnLeave", function() if not sf.dragging then tcol(0.55) end end)
    thumb:SetScript("OnMouseDown", function(self2)
        sf.dragging = true; local _, cy = GetCursorPosition(); sf.dc, sf.doff = cy, sf.offset
        self2:SetScript("OnUpdate", function()
            local maxOff = math.max(0, totalRows() - rowsVis); local range = track:GetHeight() - thumb:GetHeight()
            local _, ny = GetCursorPosition(); local moved = (sf.dc - ny) / sf:GetEffectiveScale()
            if range > 0 and maxOff > 0 then sf.offset = math.min(maxOff, math.max(0, math.floor(sf.doff + (moved / range) * maxOff + 0.5))); sf:Refresh() end
        end)
    end)
    thumb:SetScript("OnMouseUp", function(self2) sf.dragging = false; self2:SetScript("OnUpdate", nil); tcol(0.55) end)
    function sf:Refresh()
        local tr = totalRows(); local maxOff = math.max(0, tr - rowsVis); if self.offset > maxOff then self.offset = maxOff end
        for i, cell in ipairs(self.cells) do
            local idx = self.offset * cols + i; local absRow = self.offset + math.floor((i - 1) / cols)
            cell.zebra:SetShown(absRow % 2 == 1)
            local d = self.data[idx]; if d then cell.data = d; update(cell, d); cell:Show() else cell.data = nil; cell:Hide() end
        end
        local th = track:GetHeight()
        if tr > rowsVis and th > 0 then local thumbH = math.max(18, th * rowsVis / tr); local range = th - thumbH; thumb:SetHeight(thumbH); thumb:ClearAllPoints(); thumb:SetPoint("TOP", 0, -(maxOff > 0 and (self.offset / maxOff) or 0) * range); track:Show() else track:Hide() end
    end
    function sf:SetData(list) self.data = list or {}; self:Refresh() end
    sf:EnableMouseWheel(true); sf:SetScript("OnMouseWheel", function(self2, delta) self2.offset = math.max(0, self2.offset - delta); self2:Refresh() end)
    return sf
end

-- ---------------------------------------------------------------------------
-- Raider picker
-- ---------------------------------------------------------------------------
local win
local picker
local openCharPicker
local function buildPicker()
    picker = CreateFrame("Frame", "HexAuraSoundsPicker", UIParent)
    picker:SetSize(180, 278); picker:SetFrameStrata("FULLSCREEN_DIALOG")
    bg(picker, 0.06, 0.065, 0.075, 0.99); stroke(picker, GOLD, 1)
    picker.catcher = CreateFrame("Button", nil, UIParent); picker.catcher:SetAllPoints(UIParent); picker.catcher:SetFrameStrata("FULLSCREEN_DIALOG"); picker.catcher:Hide()
    picker.catcher:RegisterForClicks("AnyDown")
    picker.catcher:SetScript("OnClick", function(_, button)
        if button == "RightButton" and RAS.uiCharRows then
            for _, row in ipairs(RAS.uiCharRows) do if row:IsShown() and row.data and not row.data.filler and not row.data.header and row:IsMouseOver() then openCharPicker(row); return end end
        end
        picker:Hide()
    end)
    picker:SetFrameLevel(picker.catcher:GetFrameLevel() + 10)
    picker:SetScript("OnHide", function() picker.catcher:Hide(); picker.search:ClearFocus(); if RAS.SetPickerChar then RAS:SetPickerChar(nil) end end)

    picker.search = makeEdit(picker, 172, "search"); picker.search:SetPoint("TOPLEFT", 4, -4)
    picker.search:SetScript("OnTextChanged", function(self2) self2.ph:SetShown(self2:GetText() == "" and not self2:HasFocus()); picker:Populate() end)
    picker.search:SetScript("OnEscapePressed", function() picker:Hide() end)
    picker.search:SetScript("OnEnterPressed", function() local d = picker.list.data and picker.list.data[1]; if d and picker.onPick then picker.onPick(d.name) end picker:Hide() end)

    picker.list = scroll(picker, 172, 244, 20,
        function(sf)
            local r = CreateFrame("Button", nil, sf); r:RegisterForClicks("LeftButtonDown"); r.name = fs(r, 12, TEXT); r.name:SetPoint("LEFT", 8, 0)
            r:SetScript("OnEnter", function() r.hl:SetColorTexture(1, 1, 1, 0.06) end)
            r:SetScript("OnLeave", function() r.hl:SetColorTexture(1, 1, 1, 0) end)
            r:SetScript("OnClick", function() if r.data and picker.onPick then picker.onPick(r.data.name) end picker:Hide() end)
            return r
        end,
        function(row, d) row.name:SetText(d.name) end)
    picker.list:SetPoint("TOPLEFT", 4, -28)
    function picker:Populate()
        local q = self.search:GetText():lower(); local data = {}
        for _, name in ipairs(RAS.playerOrder) do if q == "" or name:lower():find(q, 1, true) then data[#data + 1] = { name = name } end end
        self.list:SetData(data)
    end
end
local function showPicker(anchor, onPick)
    if not picker then buildPicker() end
    picker.onPick = onPick; picker.search:SetText(""); picker:Populate()
    if win then picker:SetScale(win:GetEffectiveScale() / UIParent:GetEffectiveScale()) end
    picker:ClearAllPoints(); picker:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
    picker.catcher:Show(); picker:Show(); picker:Raise(); picker.search:SetFocus()
end

-- tiny context menu at the cursor: items = { {text=, color=, onClick=}, ... }
local menu
local function showMenu(items)
    if not menu then
        menu = CreateFrame("Frame", "HexAuraSoundsMenu", UIParent); menu:SetFrameStrata("FULLSCREEN_DIALOG")
        bg(menu, 0.07, 0.075, 0.085, 0.99); stroke(menu, GOLD, 1)
        menu.catcher = CreateFrame("Button", nil, UIParent); menu.catcher:SetAllPoints(UIParent); menu.catcher:SetFrameStrata("FULLSCREEN_DIALOG"); menu.catcher:Hide()
        menu.catcher:RegisterForClicks("AnyDown")
        menu.catcher:SetScript("OnClick", function() menu:Hide() end)
        menu:SetFrameLevel(menu.catcher:GetFrameLevel() + 10)
        menu:SetScript("OnHide", function() menu.catcher:Hide() end)
        menu.items = {}
    end
    for _, b in ipairs(menu.items) do b:Hide() end
    local MW, IH, PAD = 116, 20, 3
    for i, it in ipairs(items) do
        local b = menu.items[i]
        if not b then
            b = CreateFrame("Button", nil, menu); b:RegisterForClicks("LeftButtonDown"); b:SetSize(MW - 2 * PAD, IH)
            b.hl = b:CreateTexture(nil, "BACKGROUND"); b.hl:SetAllPoints(); b.hl:SetColorTexture(1, 1, 1, 0)
            b.t = fs(b, 12, TEXT); b.t:SetPoint("LEFT", 8, 0)
            b:SetScript("OnEnter", function() b.hl:SetColorTexture(1, 1, 1, 0.06) end)
            b:SetScript("OnLeave", function() b.hl:SetColorTexture(1, 1, 1, 0) end)
            menu.items[i] = b
        end
        b:SetPoint("TOPLEFT", PAD, -PAD - (i - 1) * IH)
        local c = it.color or TEXT; b.t:SetTextColor(c[1], c[2], c[3]); b.t:SetText(it.text)
        b:SetScript("OnClick", function() menu:Hide(); if it.onClick then it.onClick() end end)
        b:Show()
    end
    menu:SetSize(MW, PAD * 2 + #items * IH)
    if win then menu:SetScale(win:GetEffectiveScale() / UIParent:GetEffectiveScale()) end
    local scale = menu:GetEffectiveScale(); local cx, cy = GetCursorPosition()
    menu:ClearAllPoints(); menu:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", cx / scale, cy / scale)
    menu.catcher:Show(); menu:Show(); menu:Raise()
end

-- ---------------------------------------------------------------------------
-- Window
-- ---------------------------------------------------------------------------
local function build()
    local W, H = 648, 608
    local function selGroup(create) local st, sn = RAS:Selected(); return RAS:GroupTable(st, sn, create) end
    win = CreateFrame("Frame", "HexAuraSoundsFrame", UIParent)
    win:SetSize(W, H); win:SetPoint("CENTER"); win:SetFrameStrata("HIGH")
    win:SetMovable(true); win:EnableMouse(true); win:RegisterForDrag("LeftButton")
    win:SetScript("OnDragStart", win.StartMoving); win:SetScript("OnDragStop", win.StopMovingOrSizing)
    win:SetClampedToScreen(false)
    bg(win, 0.055, 0.06, 0.07, 0.98); stroke(win, {0.22, 0.19, 0.10}, 1)
    tinsert(UISpecialFrames, "HexAuraSoundsFrame")

    local title = fs(win, 15, GOLD); title:SetPoint("TOPLEFT", 16, -14); title:SetText("Hex Aura Sounds")
    local close = softButton(win, "\195\151", 34, 34, function() win:Hide() end, MUTED); close:SetPoint("TOPRIGHT", -6, -6)
    do local fp = close.t:GetFont(); if not close.t:SetFont(FONT, 28, "") then close.t:SetFont(fp, 28, "") end end
    local enLabel = fs(win, 12, MUTED); enLabel:SetText("Enabled")
    local sw = makeSwitch(win, function() return RAS.db.enabled end, function(v) RAS.db.enabled = v; RAS:Rebuild() end)
    sw:SetPoint("TOPRIGHT", close, "TOPLEFT", -14, -9); enLabel:SetPoint("RIGHT", sw, "LEFT", -8, 0); win.sw = sw

    -- SPELLS -----------------------------------------------------------------
    local sHead = fs(win, 11, GOLD); sHead:SetPoint("TOPLEFT", 16, -48); sHead:SetText("TRACKED SPELLS")
    win.sCount = fs(win, 11, MUTED); win.sCount:SetPoint("LEFT", sHead, "RIGHT", 8, 0)
    win.spellSub = fs(win, 11, GOLD); win.spellSub:SetPoint("LEFT", win.sCount, "RIGHT", 10, 0)
    local addBox = makeEdit(win, 150, "add spellID", function(txt)
        local id = tonumber(txt)
        if id then selGroup(true)[id] = true; RAS:Rebuild(); win.addBox:SetText(""); win:Refresh()
            if C_Spell and C_Spell.RequestLoadSpellData then C_Spell.RequestLoadSpellData(id) end
        end
    end)
    addBox:SetPoint("TOPLEFT", 16, -66); win.addBox = addBox
    local addBtn = softButton(win, "+ add", 46, 20, function() addBox:GetScript("OnEnterPressed")(addBox) end); addBtn:SetPoint("LEFT", addBox, "RIGHT", 6, 0)

    local spellGrid = gridScroll(win, W - 32, 94, 4, 30,
        function(sf)
            local c = CreateFrame("Button", nil, sf); c:RegisterForClicks("LeftButtonDown", "RightButtonDown")
            local function toggle() if not c.data then return end local g = selGroup(true); local cur = g[c.data.id]; g[c.data.id] = not cur and true or false; RAS:Rebuild(); win:Refresh() end
            c.tog = vToggle(c, 6, 16, function() local g = selGroup(false); return c.data and g and g[c.data.id] end, function() toggle() end)
            c.tog:SetPoint("LEFT", 4, 0)
            c.icon = makeIcon(c, 18); c.icon:SetPoint("LEFT", c.tog, "RIGHT", 5, 0)
            c.name = fs(c, 11, TEXT); c.name:SetPoint("LEFT", c.icon, "RIGHT", 5, -2); c.name:SetPoint("RIGHT", -14, -2); c.name:SetJustifyH("LEFT"); c.name:SetWordWrap(false)
            c.id = fs(c, 9, MUTED); c.id:SetPoint("TOPRIGHT", -3, -2)
            c.delayMark = fs(c, 12, GREEN); c.delayMark:SetPoint("RIGHT", -4, -1); c.delayMark:SetText("D"); c.delayMark:Hide()
            c:SetScript("OnClick", function(_, btn)
                if not c.data then return end
                if btn == "RightButton" then
                    local id = c.data.id; local st, sn = RAS:Selected(); local dl = RAS:IsDelayed(st, sn, id)
                    showMenu({
                        { text = dl and "Undo Delay" or "Delay", color = GREEN, onClick = function() RAS:SetDelayed(st, sn, id, not dl); RAS:Rebuild(); win:Refresh() end },
                        { text = "Remove", color = RED, onClick = function() local g = selGroup(true); g[id] = nil; RAS:SetDelayed(st, sn, id, false); RAS:Rebuild(); win:Refresh() end },
                    })
                else toggle() end
            end)
            c:SetScript("OnEnter", function() c.hl:SetColorTexture(1, 1, 1, 0.05); if c.data then GameTooltip:SetOwner(c, "ANCHOR_RIGHT"); GameTooltip:SetSpellByID(c.data.id); GameTooltip:Show() end end)
            c:SetScript("OnLeave", function() c.hl:SetColorTexture(1, 1, 1, 0); GameTooltip:Hide() end)
            return c
        end,
        function(cell, d)
            local st, sn = RAS:Selected()
            local g = RAS:GroupTable(st, sn, false); local on = g and g[d.id] and true or false
            local tex = (C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(d.id)) or 134400
            local nm = (C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(d.id)) or ("Spell " .. d.id)
            cell.icon.tex:SetTexture(tex); cell.icon.tex:SetDesaturated(not on)
            cell.name:SetText(trunc(nm, 18))
            cell.name:SetTextColor(on and TEXT[1] or MUTED[1], on and TEXT[2] or MUTED[2], on and TEXT[3] or MUTED[3])
            cell.id:SetText(d.id)
            cell.delayMark:SetShown(RAS:IsDelayed(st, sn, d.id))
            cell.tog:refresh()
        end)
    spellGrid:SetPoint("TOPLEFT", 16, -90); win.spellGrid = spellGrid

    -- tier-1 selector: Raid / Mythic+ / Custom (each loads its own button pack)
    local barW = W - 32
    local tlabels = { raid = "Raid", mplus = "Mythic+", custom = "Custom" }
    local t1w = barW / 3
    win.tier1 = {}
    do
        local i = 0
        for _, tier in ipairs({ "raid", "mplus", "custom" }) do
            local b = CreateFrame("Button", nil, win); b:RegisterForClicks("LeftButtonDown"); b:SetSize(t1w, 20); b:SetPoint("TOPLEFT", 16 + i * t1w, -194)
            bg(b, 0.12, 0.13, 0.15, 1); stroke(b, HAIR, 1)
            b.selbg = b:CreateTexture(nil, "BORDER"); b.selbg:SetAllPoints(); b.selbg:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.22); b.selbg:Hide()
            local hov = b:CreateTexture(nil, "HIGHLIGHT"); hov:SetAllPoints(); hov:SetColorTexture(1, 1, 1, 0.05)
            b.t = fs(b, 12, GOLD); b.t:SetPoint("CENTER"); b.t:SetText(tlabels[tier]); b.tier = tier
            b.bar = b:CreateTexture(nil, "OVERLAY"); b.bar:SetPoint("BOTTOMLEFT", 1, 1); b.bar:SetPoint("BOTTOMRIGHT", -1, 1); b.bar:SetHeight(3); b.bar:SetColorTexture(GREEN[1], GREEN[2], GREEN[3], 0.95); b.bar:Hide()
            b.gdot = b:CreateFontString(nil, "OVERLAY", "GameFontNormal"); b.gdot:SetFont(STANDARD_TEXT_FONT, 26, ""); b.gdot:SetTextColor(GREEN[1], GREEN[2], GREEN[3]); b.gdot:SetText("."); b.gdot:SetPoint("BOTTOMLEFT", b.t, "BOTTOMRIGHT", 3, 0); b.gdot:Hide()
            b:SetScript("OnClick", function() RAS.db.selTier = tier; RAS.db.selName = (RAS:GroupItems(tier)[1] or ""); win:Refresh() end)
            win.tier1[#win.tier1 + 1] = b; i = i + 1
        end
    end

    -- tier-2 button pool, laid out full-width for the selected tier
    win.t2pool = {}
    local function getT2(i)
        local b = win.t2pool[i]
        if not b then
            b = CreateFrame("Button", nil, win); b:RegisterForClicks("LeftButtonDown")
            bg(b, 0.10, 0.11, 0.125, 1); stroke(b, HAIR, 1)
            b.selbg = b:CreateTexture(nil, "BORDER"); b.selbg:SetAllPoints(); b.selbg:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.22); b.selbg:Hide()
            local hov = b:CreateTexture(nil, "HIGHLIGHT"); hov:SetAllPoints(); hov:SetColorTexture(1, 1, 1, 0.06)
            b.icon = b:CreateTexture(nil, "ARTWORK"); b.icon:SetSize(30, 30); b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            b.t = fs(b, 11, TEXT)
            b.bar = b:CreateTexture(nil, "OVERLAY"); b.bar:SetPoint("BOTTOMLEFT", 1, 1); b.bar:SetPoint("BOTTOMRIGHT", -1, 1); b.bar:SetHeight(3); b.bar:SetColorTexture(GREEN[1], GREEN[2], GREEN[3], 0.95); b.bar:Hide()
            b.gdot = b:CreateFontString(nil, "OVERLAY", "GameFontNormal"); b.gdot:SetFont(STANDARD_TEXT_FONT, 26, ""); b.gdot:SetTextColor(GREEN[1], GREEN[2], GREEN[3]); b.gdot:SetText("."); b.gdot:SetPoint("BOTTOMLEFT", b.t, "BOTTOMRIGHT", 2, 0); b.gdot:Hide()
            b:SetScript("OnEnter", function() if b.fullname then GameTooltip:SetOwner(b, "ANCHOR_TOP"); GameTooltip:SetText(b.fullname, 1, 1, 1); GameTooltip:Show() end end)
            b:SetScript("OnLeave", function() GameTooltip:Hide() end)
            b:SetScript("OnClick", function() if b.name then RAS.db.selName = b.name; win:Refresh() end end)
            win.t2pool[i] = b
        end
        return b
    end
    function win:LayoutTier2()
        local st = RAS:Selected(); local items = RAS:GroupItems(st); local n = #items
        local bw = (n > 0) and (barW / n) or barW
        for _, b in ipairs(self.t2pool) do b:Hide() end
        for i, nm in ipairs(items) do
            local b = getT2(i); b:SetSize(bw, 34); b:ClearAllPoints(); b:SetPoint("TOPLEFT", 16 + (i - 1) * bw, -218)
            b.name, b.tier, b.fullname = nm, st, nm
            b.gdot:SetShown(RAS:GroupHasEnabled(st, nm))
            if st == "custom" then
                b.icon:Hide(); b.t:ClearAllPoints(); b.t:SetPoint("CENTER"); b.t:SetText(nm)
            else
                b.icon:Show(); b.icon:ClearAllPoints(); b.icon:SetPoint("LEFT", 2, 0); b.icon:SetTexture((RAS.icons and RAS.icons[nm]) or 134400)
                b.t:ClearAllPoints(); b.t:SetPoint("LEFT", b.icon, "RIGHT", 5, 0); b.t:SetText(RAS.Abbrev(nm))
            end
            b:Show()
        end
    end

    -- CHARACTERS -------------------------------------------------------------
    local charGrid = gridScroll(win, W - 32, 238, 2, 18,
        function(sf)
            local r = CreateFrame("Button", nil, sf); r:RegisterForClicks("LeftButtonDown", "RightButtonDown")
            r.sel = r:CreateTexture(nil, "BORDER"); r.sel:SetAllPoints(); r.sel:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.16); r.sel:Hide()
            r.divline = r:CreateTexture(nil, "ARTWORK"); r.divline:SetHeight(1); r.divline:SetPoint("LEFT", 6, 0); r.divline:SetPoint("RIGHT", -6, 0); r.divline:SetColorTexture(0.35, 0.30, 0.16, 1); r.divline:Hide()
            r.dot = r:CreateTexture(nil, "OVERLAY"); r.dot:SetSize(6, 6); r.dot:SetPoint("LEFT", 6, 0)
            r.name = fs(r, 11, TEXT); r.name:SetPoint("LEFT", 16, 0); r.name:SetWidth(86); r.name:SetJustifyH("LEFT"); r.name:SetWordWrap(false)
            r.tok = fs(r, 10, MUTED); r.tok:SetPoint("LEFT", 106, 0); r.tok:SetWidth(42); r.tok:SetJustifyH("LEFT")
            r.snd = fs(r, 11, MUTED); r.snd:SetPoint("LEFT", 150, 0); r.snd:SetWidth(118); r.snd:SetJustifyH("LEFT"); r.snd:SetWordWrap(false)
            r.play = iconButton(r, SPEAKER, 16, function() if r.data and not r.data.filler and not r.data.header then RAS:TestPlay(r.data.name) end end); r.play:SetPoint("RIGHT", -6, 0)
            r:SetScript("OnEnter", function() if not (r.data and (r.data.filler or r.data.header)) then r.hl:SetColorTexture(1, 1, 1, 0.05) end end)
            r:SetScript("OnLeave", function() r.hl:SetColorTexture(1, 1, 1, 0) end)
            r:SetScript("OnClick", function(_, btn) if not r.data or r.data.filler or r.data.header then return end if btn == "RightButton" then openCharPicker(r) else RAS:EditChar(r.data.name) end end)
            return r
        end,
        function(cell, d)
            if d.header then
                cell:SetAlpha(1); cell.sel:Hide(); cell.dot:Hide(); cell.play:Hide(); cell.divline:Hide()
                cell.tok:SetText(""); cell.snd:SetText("")
                cell.name:SetTextColor(GOLD[1], GOLD[2], GOLD[3]); cell.name:SetText(d.header)
                return
            end
            if d.filler then
                cell:SetAlpha(1); cell.sel:Hide(); cell.dot:Hide(); cell.play:Hide()
                cell.name:SetText(""); cell.tok:SetText(""); cell.snd:SetText("")
                cell.divline:SetShown(d.filler == "div")
                return
            end
            cell.divline:Hide(); cell.dot:Show(); cell.play:Show()
            cell:SetAlpha(d.inGroup and 1 or 0.65)
            cell.sel:SetShown(picker ~= nil and picker:IsShown() and win.pickerChar ~= nil and d.name == win.pickerChar)
            if d.inGroup then cell.dot:SetColorTexture(GREEN[1], GREEN[2], GREEN[3], 1) else cell.dot:SetColorTexture(0.32, 0.33, 0.37, 1) end
            local cc = d.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[d.class]
            if cc then cell.name:SetTextColor(cc.r, cc.g, cc.b) else cell.name:SetTextColor(TEXT[1], TEXT[2], TEXT[3]) end
            cell.name:SetText(d.name); cell.tok:SetText(d.token or "")
            if d.raider then cell.snd:SetTextColor(TEXT[1], TEXT[2], TEXT[3]); cell.snd:SetText(d.raider) else cell.snd:SetTextColor(RED[1], RED[2], RED[3]); cell.snd:SetText("none") end
        end)
    charGrid:SetPoint("TOPLEFT", 16, -292); win.charGrid = charGrid
    RAS.uiCharRows = charGrid.cells

    -- column headers over each of the two columns
    local function chHead(text, x) local hh = fs(win, 10, GOLD); hh:SetPoint("BOTTOMLEFT", charGrid, "TOPLEFT", x, 4); hh:SetText(text) end
    for col = 0, 1 do local base = 2 + col * charGrid.cellW; chHead("CHARACTER", base + 16); chHead("UNITID", base + 106); chHead("RAIDER", base + 150) end

    local searchBox = makeEdit(win, 130, "search"); searchBox:SetPoint("BOTTOMRIGHT", charGrid, "TOPRIGHT", 0, 18)
    searchBox:SetScript("OnTextChanged", function(self2) self2.ph:SetShown(self2:GetText() == "" and not self2:HasFocus()); win:Refresh() end); win.searchBox = searchBox

    -- editor -----------------------------------------------------------------
    local eLabel = fs(win, 10, MUTED); eLabel:SetPoint("TOPLEFT", charGrid, "BOTTOMLEFT", 2, -12)
    eLabel:SetText("JOIN A CHARACTER TO A PLAYER SOUND  (right-click a row for a quick pick; right-click a field to clear)")
    local nameBox = makeEdit(win, 150, "character name"); nameBox:SetPoint("TOPLEFT", charGrid, "BOTTOMLEFT", 0, -28); win.nameBox = nameBox
    local raiderBtn = CreateFrame("Button", nil, win); raiderBtn:SetSize(150, 20); bg(raiderBtn, 0.095, 0.105, 0.12); stroke(raiderBtn, HAIR, 1)
    raiderBtn:RegisterForClicks("LeftButtonDown", "RightButtonDown")
    raiderBtn.t = fs(raiderBtn, 12, MUTED); raiderBtn.t:SetPoint("LEFT", 8, 0); raiderBtn.t:SetText("pick raider")
    local ar = raiderBtn:CreateTexture(nil, "ARTWORK"); ar:SetSize(12, 12); ar:SetPoint("RIGHT", -6, 0); ar:SetTexture(ARROW); ar:SetVertexColor(0.72, 0.75, 0.80)
    raiderBtn:SetPoint("LEFT", nameBox, "RIGHT", 8, 0); win.editorRaider = nil
    local function setRaider(r) win.editorRaider = r; if r then raiderBtn.t:SetTextColor(TEXT[1], TEXT[2], TEXT[3]); raiderBtn.t:SetText(r) else raiderBtn.t:SetTextColor(MUTED[1], MUTED[2], MUTED[3]); raiderBtn.t:SetText("pick raider") end end
    win.setEditorRaider = setRaider
    local function clearEditor() nameBox:SetText(""); setRaider(nil) end
    raiderBtn:SetScript("OnClick", function(_, btn) if btn == "RightButton" then clearEditor() else showPicker(raiderBtn, setRaider) end end)
    nameBox:SetScript("OnMouseDown", function(_, btn) if btn == "RightButton" then clearEditor() end end)

    local function saveJoin()
        local nm = nameBox:GetText():gsub("^%s+", ""):gsub("%s+$", ""); if nm == "" then return end
        if win.editorRaider then RAS.db.charRaider[nm] = win.editorRaider
        elseif RAS:IsSeeded(nm) then print("|cffe0544eRAS:|r " .. nm .. " is defined in raiders.lua; pick a raider (can't unassign it)."); return
        else RAS.db.charRaider[nm] = nil end
        RAS:Rebuild(); win:Refresh()
    end
    local saveBtn = softButton(win, "save", 44, 20, saveJoin); saveBtn:SetPoint("LEFT", raiderBtn, "RIGHT", 8, 0)
    local clearBtn = softButton(win, "remove", 54, 20, function()
        local nm = nameBox:GetText():gsub("^%s+", ""):gsub("%s+$", ""); if nm == "" then return end
        if RAS:IsSeeded(nm) then print("|cffe0544eRAS:|r " .. nm .. " is defined in raiders.lua and can't be removed here."); return end
        RAS.db.charRaider[nm] = nil; RAS:Rebuild(); nameBox:SetText(""); setRaider(nil); win:Refresh()
    end, MUTED)
    clearBtn:SetPoint("LEFT", saveBtn, "RIGHT", 4, 0); win.clearBtn = clearBtn
    local function updateRemoveLabel() local nm = nameBox:GetText():gsub("^%s+", ""):gsub("%s+$", ""); clearBtn.t:SetText((nm ~= "" and RAS:IsSeeded(nm)) and "locked" or "remove") end
    nameBox:SetScript("OnTextChanged", function(self2) self2.ph:SetShown(self2:GetText() == "" and not self2:HasFocus()); updateRemoveLabel() end)
    nameBox:SetScript("OnEnterPressed", function() saveJoin(); nameBox:ClearFocus() end)

    -- footer + scale ---------------------------------------------------------
    win.status = fs(win, 11, MUTED); win.status:SetPoint("BOTTOMLEFT", 16, 12)
    local function applyScaleKeepTopLeft(v)
        local left, top = win:GetLeft(), win:GetTop(); if not (left and top) then win:SetScale(v); return end
        local sx, sy = left * win:GetEffectiveScale(), top * win:GetEffectiveScale(); win:SetScale(v)
        local newEff = win:GetEffectiveScale(); win:ClearAllPoints(); win:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", sx / newEff, sy / newEff)
    end
    win:SetScale(RAS.db.scale or 1)
    local scaleLbl = fs(win, 11, MUTED); scaleLbl:SetText("Scale")
    local scaleSlider = makeMiniSlider(win, { width = 108, thumbW = 44, min = 0.75, max = 2.0, step = 0.05,
        get = function() return RAS.db.scale or 1 end, format = function(v) return ("%d%%"):format(math.floor(v * 100 + 0.5)) end,
        onChange = function(v, done) if not done then return end RAS.db.scale = v; applyScaleKeepTopLeft(v) end })
    scaleSlider:SetPoint("BOTTOMRIGHT", -14, 10); scaleLbl:SetPoint("RIGHT", scaleSlider, "LEFT", -6, 0); win.scaleSlider = scaleSlider

    function win:Refresh()
        self.sw:refresh(); if self.scaleSlider then self.scaleSlider:SyncValue() end
        -- spell selection + tier highlight
        local st, sn = RAS:Selected()
        self.spellSub:SetText(sn ~= "" and sn or "")
        for _, b in ipairs(self.tier1 or {}) do local seld = b.tier == st; b.selbg:SetShown(seld); b.bar:SetShown(seld); b.gdot:SetShown(RAS:TierHasEnabled(b.tier)) end
        self:LayoutTier2()
        for _, b in ipairs(self.t2pool or {}) do local seld = b:IsShown() and b.name == sn; b.selbg:SetShown(seld); b.bar:SetShown(seld) end
        -- spells for the selected group
        local spells = RAS:GroupTracked(st, sn); self.sCount:SetText(#spells)
        local slist, needLoad = {}, false
        for _, s in ipairs(spells) do slist[#slist + 1] = { id = s }; if C_Spell and C_Spell.GetSpellName and not C_Spell.GetSpellName(s) then needLoad = true; if C_Spell.RequestLoadSpellData then C_Spell.RequestLoadSpellData(s) end end end
        self.spellGrid:SetData(slist)
        if needLoad and not self._pl then self._pl = true; C_Timer.After(0.4, function() self._pl = nil; if self:IsShown() then self:Refresh() end end) end
        -- characters
        local q = self.searchBox:GetText():lower()
        local cols, rlist = 2, {}
        local function charEntry(name, token)
            return { name = name, raider = RAS:CharRaider(name), inGroup = true, token = token, class = token and select(2, UnitClass(token)) }
        end

        if q ~= "" then
            -- search: flat filtered list, in-group first, then a divider, then the rest
            local roster = RAS:BuildRoster(); local inGroup, tokenOf, classOf, seen, names = {}, {}, {}, {}, {}
            for token, nm in pairs(roster) do inGroup[nm] = true; tokenOf[nm] = token; local _, cls = UnitClass(token); classOf[nm] = cls end
            local function add(nm) if nm and not seen[nm] then seen[nm] = true; names[#names + 1] = nm end end
            for _, nm in pairs(roster) do add(nm) end
            for nm in pairs(RAS.db.charRaider) do add(nm) end
            for nm in pairs(RAS.charSeed or {}) do add(nm) end
            table.sort(names, function(a, b)
                local ga, gb = inGroup[a] and true or false, inGroup[b] and true or false
                if ga ~= gb then return ga end
                return a < b
            end)
            local filtered = {}
            for _, nm in ipairs(names) do
                local raider = RAS:CharRaider(nm)
                if nm:lower():find(q, 1, true) or (raider and raider:lower():find(q, 1, true)) then
                    filtered[#filtered + 1] = { name = nm, raider = raider, inGroup = inGroup[nm], token = tokenOf[nm], class = classOf[nm] }
                end
            end
            local firstOther
            for i, e in ipairs(filtered) do if not e.inGroup then firstOther = i break end end
            if firstOther and firstOther > 1 then
                for i = 1, firstOther - 1 do rlist[#rlist + 1] = filtered[i] end
                while (#rlist % cols) ~= 0 do rlist[#rlist + 1] = { filler = "pad" } end
                for _ = 1, cols do rlist[#rlist + 1] = { filler = "div" } end
                for i = firstOther, #filtered do rlist[#rlist + 1] = filtered[i] end
            else
                for _, e in ipairs(filtered) do rlist[#rlist + 1] = e end
            end
        else
            local inGroupSet = {}
            if IsInRaid() then
                -- lay out by subgroup: odd parties in the left column, even in the right
                local subgroups, nameToken = {}, {}
                for i = 1, GetNumGroupMembers() do
                    local rname, _, sub = GetRaidRosterInfo(i)
                    if rname then
                        rname = rname:match("^[^-]+") or rname; sub = sub or 1
                        subgroups[sub] = subgroups[sub] or {}; subgroups[sub][#subgroups[sub] + 1] = rname
                        nameToken[rname] = "raid" .. i; inGroupSet[rname] = true
                    end
                end
                local maxP = 0; for p in pairs(subgroups) do if p > maxP then maxP = p end end
                for ps = 1, maxP, 2 do
                    local lL, lR = subgroups[ps], subgroups[ps + 1]
                    if lL or lR then
                        rlist[#rlist + 1] = lL and { header = "Party " .. ps } or { filler = "blank" }
                        rlist[#rlist + 1] = lR and { header = "Party " .. (ps + 1) } or { filler = "blank" }
                        local rows = math.max(lL and #lL or 0, lR and #lR or 0)
                        for r = 1, rows do
                            local nL, nR = lL and lL[r], lR and lR[r]
                            rlist[#rlist + 1] = nL and charEntry(nL, nameToken[nL]) or { filler = "blank" }
                            rlist[#rlist + 1] = nR and charEntry(nR, nameToken[nR]) or { filler = "blank" }
                        end
                        rlist[#rlist + 1] = { filler = "blank" }; rlist[#rlist + 1] = { filler = "blank" }
                    end
                end
            elseif IsInGroup() then
                -- party: left column only
                local members = { { UnitName("player"), "player" } }
                for i = 1, GetNumGroupMembers() - 1 do members[#members + 1] = { UnitName("party" .. i), "party" .. i } end
                for _, m in ipairs(members) do
                    if m[1] then inGroupSet[m[1]] = true; rlist[#rlist + 1] = charEntry(m[1], m[2]); rlist[#rlist + 1] = { filler = "blank" } end
                end
            else
                local pn = UnitName("player")
                if pn then inGroupSet[pn] = true; rlist[#rlist + 1] = charEntry(pn, "player"); rlist[#rlist + 1] = { filler = "blank" } end
            end
            -- off-roster assigned characters, flat, below a divider
            local others, oseen = {}, {}
            local function addOther(nm) if nm and not inGroupSet[nm] and not oseen[nm] then oseen[nm] = true; others[#others + 1] = nm end end
            for nm in pairs(RAS.db.charRaider) do addOther(nm) end
            for nm in pairs(RAS.charSeed or {}) do addOther(nm) end
            table.sort(others)
            if #others > 0 then
                while (#rlist % cols) ~= 0 do rlist[#rlist + 1] = { filler = "blank" } end
                for _ = 1, cols do rlist[#rlist + 1] = { filler = "div" } end
                for _, nm in ipairs(others) do rlist[#rlist + 1] = { name = nm, raider = RAS:CharRaider(nm), inGroup = false } end
            end
        end
        self.charGrid:SetData(rlist)
        local api = RAS:HasAPI() and "" or "|cffe0544eAPI missing|r   "
        self.status:SetText(api .. (RAS.db.enabled and "|cff4cd07aon|r" or "|cff888888off|r") .. "   live regs: " .. (RAS.lastCount or 0) .. (RAS.lastMissing and RAS.lastMissing > 0 and ("   |cffe0544e" .. RAS.lastMissing .. " unassigned|r") or ""))
    end

    win:Hide()
end

function RAS:Toggle() if not win then build() end if win:IsShown() then win:Hide() else win:Show(); win:Refresh() end end
function RAS:RefreshUI() if win and win:IsShown() then win:Refresh() end end
function RAS:SetPickerChar(name) if not win then return end win.pickerChar = name; if win:IsShown() then win:Refresh() end end
function openCharPicker(row)
    if not win or not row or not row.data or row.data.filler or row.data.header then return end
    local charName = row.data.name; win.pickerChar = charName
    showPicker(row.snd, function(raider) RAS.db.charRaider[charName] = raider; RAS:Rebuild(); win:Refresh() end)
    win:Refresh()
end
function RAS:EditChar(name)
    if not win then build() end
    if not win:IsShown() then win:Show() end
    win.nameBox:SetText(name or ""); win.nameBox.ph:SetShown(false); win.setEditorRaider(RAS:CharRaider(name)); win:Refresh(); win.nameBox:SetFocus()
end