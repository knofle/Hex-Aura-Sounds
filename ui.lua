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
local BLUE  = {0.45, 0.72, 1.00}

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
    picker:SetSize(260, 278); picker:SetFrameStrata("FULLSCREEN_DIALOG")
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

    picker.search = makeEdit(picker, 252, "search"); picker.search:SetPoint("TOPLEFT", 4, -4)
    picker.search:SetScript("OnTextChanged", function(self2) self2.ph:SetShown(self2:GetText() == "" and not self2:HasFocus()); picker:Populate() end)
    picker.search:SetScript("OnEscapePressed", function() picker:Hide() end)
    picker.search:SetScript("OnEnterPressed", function() local d = picker.list.data and picker.list.data[1]; if d and picker.onPick then picker.onPick(d.name, d.none) end picker:Hide() end)

    picker.list = scroll(picker, 252, 244, 20,
        function(sf)
            local r = CreateFrame("Button", nil, sf); r:RegisterForClicks("LeftButtonDown")
            r.name = fs(r, 12, TEXT); r.name:SetPoint("LEFT", 8, 0); r.name:SetPoint("RIGHT", -22, 0); r.name:SetJustifyH("LEFT"); r.name:SetWordWrap(false)
            r.play = iconButton(r, SPEAKER, 14, function() if r.data and picker.preview then picker.preview(r.data.name) end end); r.play:SetPoint("RIGHT", -4, 0)
            r:SetScript("OnEnter", function() r.hl:SetColorTexture(1, 1, 1, 0.06) end)
            r:SetScript("OnLeave", function() r.hl:SetColorTexture(1, 1, 1, 0) end)
            r:SetScript("OnClick", function() if r.data and picker.onPick then picker.onPick(r.data.name, r.data.none) end picker:Hide() end)
            return r
        end,
        function(row, d)
            row.name:SetText(d.name); row.name:SetTextColor(d.none and MUTED[1] or TEXT[1], d.none and MUTED[2] or TEXT[2], d.none and MUTED[3] or TEXT[3])
            row.play:SetShown(picker.preview ~= nil and not d.none)
        end)
    picker.list:SetPoint("TOPLEFT", 4, -28)
    -- source: list of names (default: raiders); none: optional "clear" entry on top
    function picker:Populate()
        local q = self.search:GetText():lower(); local data = {}
        if self.none and q == "" then data[1] = { name = self.none, none = true } end
        for _, name in ipairs(self.source or RAS.playerOrder) do if q == "" or name:lower():find(q, 1, true) then data[#data + 1] = { name = name } end end
        self.list:SetData(data)
    end
end
-- opts (optional): { source = {names}, preview = function(name), none = "label",
--   attached = true: opens to the right of anchor as part of a menu (the menu
--   handles outside clicks and closes it) }
local function showPicker(anchor, onPick, opts)
    if not picker then buildPicker() end
    opts = opts or {}
    picker.source, picker.preview, picker.none, picker.attached = opts.source, opts.preview, opts.none, opts.attached
    picker.onPick = onPick; picker.search:SetText(""); picker:Populate()
    if win then picker:SetScale(win:GetEffectiveScale() / UIParent:GetEffectiveScale()) end
    picker:ClearAllPoints()
    if opts.attached then
        picker:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 4, 3)
        picker.catcher:Hide(); picker:Show(); picker:Raise()
    else
        picker:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
        picker.catcher:Show(); picker:Show(); picker:Raise(); picker.search:SetFocus()
    end
end

-- tiny context menu at the cursor: items = { {text=, color=, onClick=, sub={items}, open=function(btn)}, ... }
-- an item with sub opens a submenu to its right on hover; open() does the same with a custom frame
local menu, submenu
local MW, IH, PAD = 130, 20, 3   -- MW = minimum width; menus grow to fit their longest item
local function fillMenu(m, items, onHover)
    for _, b in ipairs(m.items) do b:Hide() end
    for i, it in ipairs(items) do
        local b = m.items[i]
        if not b then
            b = CreateFrame("Button", nil, m); b:RegisterForClicks("LeftButtonDown"); b:SetSize(MW - 2 * PAD, IH)
            b.hl = b:CreateTexture(nil, "BACKGROUND"); b.hl:SetAllPoints(); b.hl:SetColorTexture(1, 1, 1, 0)
            b.t = fs(b, 12, TEXT); b.t:SetPoint("LEFT", 8, 0)
            b.arrow = b:CreateTexture(nil, "ARTWORK"); b.arrow:SetSize(10, 10); b.arrow:SetPoint("RIGHT", -4, 0)
            b.arrow:SetTexture(ARROW); b.arrow:SetRotation(math.pi / 2); b.arrow:SetVertexColor(0.72, 0.75, 0.80)
            b:SetScript("OnLeave", function() b.hl:SetColorTexture(1, 1, 1, 0); GameTooltip:Hide() end)
            m.items[i] = b
        end
        b:SetPoint("TOPLEFT", PAD, -PAD - (i - 1) * IH)
        -- disabled items are greyed out and can't be clicked; tip explains why
        local c = it.disabled and MUTED or it.color or TEXT; b.t:SetTextColor(c[1], c[2], c[3]); b.t:SetText(it.text)
        b.arrow:SetShown(it.sub ~= nil or it.open ~= nil)
        b:SetScript("OnEnter", function()
            if not it.disabled then b.hl:SetColorTexture(1, 1, 1, 0.06) end
            if it.tip then GameTooltip:SetOwner(b, "ANCHOR_RIGHT"); GameTooltip:SetText(it.tip, 1, 1, 1, 1, true); GameTooltip:Show() end
            if onHover then onHover(b, it) end
        end)
        b:SetScript("OnClick", function()
            if it.disabled then return end
            if it.sub or it.open then if onHover then onHover(b, it) end return end
            menu:Hide(); if it.onClick then it.onClick() end
        end)
        b:Show()
    end
    -- width: fit the longest item (text + room for the arrow)
    local w = MW
    for i = 1, #items do w = math.max(w, math.ceil(m.items[i].t:GetStringWidth()) + 8 + 22 + 2 * PAD) end
    for i = 1, #items do m.items[i]:SetWidth(w - 2 * PAD) end
    m:SetSize(w, PAD * 2 + #items * IH)
end
local function showMenu(items, anchor)
    if not menu then
        menu = CreateFrame("Frame", "HexAuraSoundsMenu", UIParent); menu:SetFrameStrata("FULLSCREEN_DIALOG")
        bg(menu, 0.07, 0.075, 0.085, 0.99); stroke(menu, GOLD, 1)
        menu.catcher = CreateFrame("Button", nil, UIParent); menu.catcher:SetAllPoints(UIParent); menu.catcher:SetFrameStrata("FULLSCREEN_DIALOG"); menu.catcher:Hide()
        menu.catcher:RegisterForClicks("AnyDown")
        menu.catcher:SetScript("OnClick", function() menu:Hide() end)
        menu:SetFrameLevel(menu.catcher:GetFrameLevel() + 10)
        menu.items = {}
        submenu = CreateFrame("Frame", "HexAuraSoundsSubmenu", menu); submenu:SetFrameStrata("FULLSCREEN_DIALOG")
        bg(submenu, 0.07, 0.075, 0.085, 0.99); stroke(submenu, GOLD, 1)
        submenu:SetFrameLevel(menu:GetFrameLevel() + 10); submenu.items = {}; submenu:Hide()
        menu:SetScript("OnHide", function()
            menu.catcher:Hide(); submenu:Hide()
            if picker and picker.attached then picker:Hide() end
        end)
    end
    submenu:Hide()
    fillMenu(menu, items, function(b, it)
        local attachedOpen = picker and picker.attached and picker:IsShown()
        if it.sub then
            if attachedOpen then picker:Hide() end
            fillMenu(submenu, it.sub)
            submenu:ClearAllPoints(); submenu:SetPoint("TOPLEFT", b, "TOPRIGHT", PAD + 1, PAD)
            submenu:Show(); submenu:Raise()
        elseif it.open and not it.disabled then
            submenu:Hide()
            if not (attachedOpen and picker.openedBy == b) then it.open(b); if picker then picker.openedBy = b end end
        else
            submenu:Hide()
            if attachedOpen then picker:Hide() end
        end
    end)
    if win then menu:SetScale(win:GetEffectiveScale() / UIParent:GetEffectiveScale()) end
    menu:ClearAllPoints()
    if anchor then menu:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
    else local scale = menu:GetEffectiveScale(); local cx, cy = GetCursorPosition(); menu:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", cx / scale, cy / scale) end
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
    local close = softButton(win, "\195\151", 40, 40, function() win:Hide() end, MUTED); close:SetPoint("TOPRIGHT", -4, -4)
    do local fp = close.t:GetFont(); if not close.t:SetFont(FONT, 38, "") then close.t:SetFont(fp, 38, "") end end
    local enLabel = fs(win, 12, MUTED); enLabel:SetText("Enabled")
    local sw = makeSwitch(win, function() return RAS.db.enabled end, function(v) RAS.db.enabled = v; RAS:Rebuild() end)
    sw:SetPoint("TOPRIGHT", close, "TOPLEFT", -12, -12); enLabel:SetPoint("RIGHT", sw, "LEFT", -8, 0); win.sw = sw

    -- output channel dropdown + that channel's WoW volume
    local CHANNELS = { { "Master", "Master" }, { "Music", "Music" }, { "Effects", "SFX" }, { "Ambience", "Ambience" }, { "Dialog", "Dialog" } }
    local function chanLabel(v) for _, c in ipairs(CHANNELS) do if c[2] == v then return c[1] end end return v end
    local CHAN_TAG = { Master = "MST", Music = "MUS", SFX = "SFX", Ambience = "AMB", Dialog = "DLG" }
    -- per-spell raider filter, as shown in menus/tooltips: "Everyone", "Only 3", "Except 2"
    local function playersSummary(id)
        local sp = RAS.db.spellPlayers[id]
        if not sp or not sp.mode then return "Everyone" end
        local n = 0; for _ in pairs(sp.raiders or {}) do n = n + 1 end
        return (sp.mode == "only" and "Only " or "Except ") .. n
    end
    local volPct = fs(win, 11, MUTED); volPct:SetWidth(34); volPct:SetJustifyH("RIGHT")
    local volSlider = makeMiniSlider(win, { width = 90, height = 14, thumbW = 30, min = 0, max = 1, step = 0.05,
        get = function() return RAS:GetChannelVolume() end, format = function() return "" end,
        onChange = function(v) RAS:SetChannelVolume(v); volPct:SetText(("%d%%"):format(math.floor(v * 100 + 0.5))) end })
    volSlider:SetPoint("RIGHT", enLabel, "LEFT", -24, 0); volPct:SetPoint("RIGHT", volSlider, "LEFT", -6, 0)
    local chanBtn = CreateFrame("Button", nil, win); chanBtn:SetSize(90, 20); bg(chanBtn, 0.095, 0.105, 0.12); stroke(chanBtn, HAIR, 1)
    chanBtn:RegisterForClicks("LeftButtonDown")
    chanBtn.t = fs(chanBtn, 12, TEXT); chanBtn.t:SetPoint("LEFT", 8, 0)
    local car = chanBtn:CreateTexture(nil, "ARTWORK"); car:SetSize(12, 12); car:SetPoint("RIGHT", -6, 0); car:SetTexture(ARROW); car:SetVertexColor(0.72, 0.75, 0.80)
    local chanTog = CreateFrame("Button", nil, win); chanTog:SetSize(34, 20); bg(chanTog, 0.095, 0.105, 0.12); stroke(chanTog, HAIR, 1)
    chanTog:RegisterForClicks("LeftButtonDown")
    chanTog.t = fs(chanTog, 11, GREEN); chanTog.t:SetPoint("CENTER")
    chanTog:SetPoint("RIGHT", volPct, "LEFT", -8, 0)
    chanTog:SetScript("OnClick", function()
        if InCombatLockdown() then print("|cffe0544eRAS:|r can't change sound settings in combat."); return end
        RAS:SetChannelEnabled(not RAS:GetChannelEnabled()); win:SyncChannel()
    end)
    chanBtn:SetPoint("RIGHT", chanTog, "LEFT", -2, 0); win.chanBtn = chanBtn
    chanBtn:SetScript("OnClick", function()
        local items = {}
        for _, c in ipairs(CHANNELS) do
            local v = c[2]
            items[#items + 1] = { text = c[1], color = (v == RAS:GetChannel()) and GOLD or TEXT, onClick = function() RAS:SetChannel(v); win:Refresh() end }
        end
        showMenu(items, chanBtn)
    end)
    local chanLbl = fs(win, 12, MUTED); chanLbl:SetText("Output"); chanLbl:SetPoint("RIGHT", chanBtn, "LEFT", -6, 0)
    function win:SyncChannel()
        self.chanBtn.t:SetText(chanLabel(RAS:GetChannel())); volSlider:SyncValue()
        volPct:SetText(("%d%%"):format(math.floor(RAS:GetChannelVolume() * 100 + 0.5)))
        local on = RAS:GetChannelEnabled()
        local c = on and GREEN or RED; chanTog.t:SetTextColor(c[1], c[2], c[3]); chanTog.t:SetText(on and "ON" or "OFF")
        -- volume greyed and non-interactive while the channel is off
        volSlider:SetAlpha(on and 1 or 0.35); volSlider:EnableMouse(on); volPct:SetAlpha(on and 1 or 0.35)
    end
    -- follow WoW's own audio panel live
    win:RegisterEvent("CVAR_UPDATE"); win:SetScript("OnEvent", function() if win:IsShown() then win:SyncChannel() end end)

    -- SPELLS -----------------------------------------------------------------
    local sHead = fs(win, 11, GOLD); sHead:SetPoint("TOPLEFT", 16, -48); sHead:SetText("TRACKED SPELLS")
    win.sCount = fs(win, 11, MUTED); win.sCount:SetPoint("LEFT", sHead, "RIGHT", 8, 0)
    win.spellSub = fs(win, 11, GOLD); win.spellSub:SetPoint("LEFT", win.sCount, "RIGHT", 10, 0)
    local addBox = makeEdit(win, 150, "add spellID", function(txt)
        local id = tonumber(txt)
        -- adding an ID that's already in the group adds another copy of it
        if id then local g = selGroup(true); g[RAS:NewEntryKey(g, id)] = true; RAS:Rebuild(); win.addBox:SetText(""); win:Refresh()
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
                    local own = RAS.db.spellChannel[id]
                    -- Delay and a spell sound exclude each other (if both are already set, both stay usable to fix it)
                    local hasSnd = RAS.db.spellSound[id] ~= nil
                    local soundList = RAS:SpellSoundList()
                    local chanItems = { { text = "Default (" .. chanLabel(RAS:GetChannel()) .. ")", color = own and TEXT or GOLD, onClick = function() RAS.db.spellChannel[id] = nil; RAS:Rebuild(); win:Refresh() end } }
                    for _, ch in ipairs(CHANNELS) do
                        local v = ch[2]
                        chanItems[#chanItems + 1] = { text = ch[1], color = (own == v) and GOLD or TEXT, onClick = function() RAS.db.spellChannel[id] = v; RAS:Rebuild(); win:Refresh() end }
                    end
                    showMenu({
                        { text = dl and "Undo Delay" or "Delay", color = GREEN, onClick = function() RAS:SetDelayed(st, sn, id, not dl); RAS:Rebuild(); win:Refresh() end,
                          disabled = hasSnd and not dl, tip = (hasSnd and not dl) and "Can't delay a spell with its own sound. Set Sound to None first." or nil },
                        { text = "Channel: " .. (own and chanLabel(own) or "Default"), color = GOLD, sub = chanItems },
                        { text = "Players: " .. playersSummary(id), color = BLUE, onClick = function() win.playersWin:Open(id) end },
                        { text = "Sound: " .. (RAS.db.spellSound[id] or "Their own name"), color = TEXT,
                          disabled = (dl and not hasSnd) or not soundList,
                          tip = (dl and not hasSnd) and "Delayed spells can't have their own sound. Undo Delay first."
                              or (not soundList and "No SharedMedia sounds found (none of your addons load LibSharedMedia).") or nil,
                          open = function(b)   -- sound list opens to the right on hover, like a submenu
                            showPicker(b, function(name, none) RAS.db.spellSound[id] = (not none) and name or nil; menu:Hide(); RAS:Rebuild(); win:Refresh() end,
                                { source = soundList, preview = function(n) RAS:PreviewSpellSound(n) end, none = "Their own name", attached = true })
                          end },
                        { text = "Remove", color = RED, onClick = function()
                            local g = selGroup(true); g[id] = nil; RAS:SetDelayed(st, sn, id, false)
                            if type(id) == "string" then   -- a copy: drop its settings so a new copy starts clean
                                RAS.db.spellChannel[id], RAS.db.spellPlayers[id], RAS.db.spellSound[id] = nil, nil, nil
                            end
                            RAS:Rebuild(); win:Refresh()
                        end },
                    })
                else toggle() end
            end)
            c:SetScript("OnEnter", function()
                c.hl:SetColorTexture(1, 1, 1, 0.05)
                if not c.data then return end
                GameTooltip:SetOwner(c, "ANCHOR_RIGHT"); GameTooltip:SetSpellByID(c.data.sid)
                local ch = RAS.db.spellChannel[c.data.id]
                if ch then GameTooltip:AddLine("Channel: " .. chanLabel(ch), GOLD[1], GOLD[2], GOLD[3]) end
                local sp = RAS.db.spellPlayers[c.data.id]
                if sp and sp.mode then GameTooltip:AddLine("Players: " .. playersSummary(c.data.id), BLUE[1], BLUE[2], BLUE[3]) end
                local snd = RAS.db.spellSound[c.data.id]
                if snd then GameTooltip:AddLine("Sound: " .. snd, GREEN[1], GREEN[2], GREEN[3]) end
                GameTooltip:Show()
            end)
            c:SetScript("OnLeave", function() c.hl:SetColorTexture(1, 1, 1, 0); GameTooltip:Hide() end)
            return c
        end,
        function(cell, d)
            local st, sn = RAS:Selected()
            local g = RAS:GroupTable(st, sn, false); local on = g and g[d.id] and true or false
            local tex = (C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(d.sid)) or 134400
            local nm = (C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(d.sid)) or ("Spell " .. d.sid)
            cell.icon.tex:SetTexture(tex); cell.icon.tex:SetDesaturated(not on)
            cell.name:SetText(trunc(nm, 18))
            cell.name:SetTextColor(on and TEXT[1] or MUTED[1], on and TEXT[2] or MUTED[2], on and TEXT[3] or MUTED[3])
            local ch, sp = RAS.db.spellChannel[d.id], RAS.db.spellPlayers[d.id]
            local tag = ""
            if ch then tag = tag .. " |cffcca94d" .. (CHAN_TAG[ch] or ch) .. "|r" end
            if sp and sp.mode then tag = tag .. " |cff73b8ffP|r" end
            if RAS.db.spellSound[d.id] then tag = tag .. " |cff4dcc75S|r" end
            local idx = RAS.EntryIndex(d.id)
            cell.id:SetText(d.sid .. (idx > 1 and (" |cffd9d9d9#" .. idx .. "|r") or "") .. tag)
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
            b.gdot = b:CreateFontString(nil, "OVERLAY", "GameFontNormal"); b.gdot:SetFont(STANDARD_TEXT_FONT, 26, ""); b.gdot:SetTextColor(GREEN[1], GREEN[2], GREEN[3]); b.gdot:SetText("."); b.gdot:SetPoint("BOTTOMLEFT", b.t, "BOTTOMRIGHT", 3, 4); b.gdot:Hide()
            b:SetScript("OnClick", function() RAS.db.selTier = tier; win:Refresh() end)
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
            -- round dot, pinned to the button's top-right corner so it sits the same in every box
            b.gdot = b:CreateTexture(nil, "OVERLAY"); b.gdot:SetSize(5, 5)
            b.gdot:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask"); b.gdot:SetVertexColor(GREEN[1], GREEN[2], GREEN[3])
            b.gdot:SetPoint("TOPRIGHT", -4, -4); b.gdot:Hide()
            b:SetScript("OnEnter", function() if b.fullname then GameTooltip:SetOwner(b, "ANCHOR_TOP"); GameTooltip:SetText(b.fullname, 1, 1, 1); GameTooltip:Show() end end)
            b:SetScript("OnLeave", function() GameTooltip:Hide() end)
            b:SetScript("OnClick", function() if b.name then RAS.db.selByTier = RAS.db.selByTier or {}; RAS.db.selByTier[RAS.db.selTier] = b.name; win:Refresh() end end)
            win.t2pool[i] = b
        end
        return b
    end
    function win:LayoutTier2()
        local st = RAS:Selected(); local items = RAS:GroupItems(st); local n = #items
        -- whole-pixel widths so the text and dots don't land on half pixels;
        -- the last button takes the leftover pixels
        local bw = (n > 0) and math.floor(barW / n) or barW
        for _, b in ipairs(self.t2pool) do b:Hide() end
        for i, nm in ipairs(items) do
            local w = (i == n) and (barW - (n - 1) * bw) or bw
            local b = getT2(i); b:SetSize(w, 34); b:ClearAllPoints(); b:SetPoint("TOPLEFT", 16 + (i - 1) * bw, -218)
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

    -- CHANNEL RULES popup (per raid boss) -------------------------------------
    local MAXR = 6
    -- difficulty per rule (raid difficultyIDs; nil = all)
    local DIFFS = { { "All", nil }, { "LFR", 17 }, { "Normal", 14 }, { "Heroic", 15 }, { "Mythic", 16 } }
    local function diffLabel(v) for _, d in ipairs(DIFFS) do if d[2] == v then return d[1] end end return tostring(v) end
    local MODES = { { "Mute during", "mute" }, { "Only during", "only" }, { "Volume during", "volume" } }
    local function modeLabel(v) for _, m in ipairs(MODES) do if m[2] == (v or "mute") then return m[1] end end return "Mute during" end
    local function fmtT(s) return ("%d:%02d"):format(math.floor(s / 60), s % 60) end
    local function parseT(x)
        local m, s = x:match("^(%d+):(%d%d)$"); if m then return tonumber(m) * 60 + tonumber(s) end
        return tonumber(x)
    end
    -- "3:00-4:00" / "3:00-" -> from, to (nil = open end); nil if unreadable
    local function parseRange(s)
        s = s:gsub("%s+", "")
        local a, b = s:match("^([%d:]+)%-([%d:]*)$")
        local from = a and parseT(a)
        local to = (b and b ~= "") and parseT(b) or nil
        if not from or (b ~= "" and not to) or (to and to <= from) then return nil end
        return from, to
    end
    -- "3:00-4:00, 5:00-, p2, p1.5, p2 0:05-0:20" -> windows list, or nil + the bad piece
    local function parseWindows(txt)
        local out = {}
        for tok in (txt or ""):gmatch("[^,]+") do
            tok = tok:lower():match("^%s*(.-)%s*$")
            if tok ~= "" then
                local p, rest = tok:match("^ph?a?s?e?%s*(%d+%.?%d*)%s*(.*)$")
                if p and not tok:match("^%d") then
                    local w = { stage = tonumber(p) }
                    if rest ~= "" then
                        w.from, w.to = parseRange(rest)
                        if not w.from then return nil, tok end
                    end
                    out[#out + 1] = w
                else
                    local from, to = parseRange(tok)
                    if not from then return nil, tok end
                    out[#out + 1] = { from = from, to = to }
                end
            end
        end
        return out
    end
    local function formatWindows(ws)
        local t = {}
        for _, w in ipairs(ws or {}) do
            local range = w.from and (fmtT(w.from) .. "-" .. (w.to and fmtT(w.to) or ""))
            if w.stage then t[#t + 1] = "p" .. w.stage .. (range and (" " .. range) or "")
            else t[#t + 1] = range end
        end
        return table.concat(t, ", ")
    end

    local rw = CreateFrame("Frame", "HexAuraSoundsRules", win); rw:SetSize(560, 44 + MAXR * 26 + 40)
    rw:SetPoint("CENTER"); rw:SetFrameStrata("DIALOG"); rw:EnableMouse(true)
    rw:SetMovable(true); rw:RegisterForDrag("LeftButton"); rw:SetScript("OnDragStart", rw.StartMoving); rw:SetScript("OnDragStop", rw.StopMovingOrSizing)
    bg(rw, 0.06, 0.065, 0.075, 0.99); stroke(rw, GOLD, 1); rw:Hide(); win.rulesWin = rw
    rw.title = fs(rw, 13, GOLD); rw.title:SetPoint("TOPLEFT", 12, -10)
    local rclose = softButton(rw, "\195\151", 34, 34, function() rw:Hide() end, MUTED); rclose:SetPoint("TOPRIGHT", -2, -2)
    do local fp = rclose.t:GetFont(); if not rclose.t:SetFont(FONT, 32, "") then rclose.t:SetFont(fp, 32, "") end end
    -- help lives in a hover tooltip on the "?" next to the close button
    local HELP_WINDOWS = {
        { "3:00-4:00",    "3 to 4 min into the fight" },
        { "3:00-",        "from 3 min until the end" },
        { "p2",           "all of phase 2  (p1.5 = intermission)" },
        { "p2 0:05-0:20", "5 to 20 sec into phase 2" },
        { "p2 0:05-",     "from 5 sec into phase 2 until it ends" },
    }
    local HELP_MODES = {
        { "Mute during", "channel on, off inside the windows" },
        { "Only during", "channel off, on inside the windows" },
        { "Volume during", "channel volume set to the % inside the windows" },
        { " ", "(overlapping volume rules: lowest % wins)" },
    }
    local rhelp = softButton(rw, "?", 26, 26, nil, MUTED); rhelp:SetPoint("RIGHT", rclose, "LEFT", -2, 0)
    rhelp:HookScript("OnEnter", function()
        GameTooltip:SetOwner(rhelp, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Windows  (separate with commas)", GOLD[1], GOLD[2], GOLD[3])
        for _, it in ipairs(HELP_WINDOWS) do GameTooltip:AddDoubleLine(it[1], it[2], 1, 1, 1, MUTED[1] + 0.3, MUTED[2] + 0.3, MUTED[3] + 0.3) end
        GameTooltip:AddLine("Phase windows (p2 ...) need BigWigs or DBM installed.", GREEN[1], GREEN[2], GREEN[3])
        GameTooltip:AddLine("Without one, only fight-time windows work.", GREEN[1], GREEN[2], GREEN[3])
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Modes", GOLD[1], GOLD[2], GOLD[3])
        for _, it in ipairs(HELP_MODES) do GameTooltip:AddDoubleLine(it[1], it[2], 1, 1, 1, MUTED[1] + 0.3, MUTED[2] + 0.3, MUTED[3] + 0.3) end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Master mutes ALL game sound; use Dialog, Ambience or Music.", RED[1], RED[2], RED[3])
        GameTooltip:Show()
    end)
    rhelp:HookScript("OnLeave", function() GameTooltip:Hide() end)
    local function rulesList(create)
        local r = RAS.db.rules
        if create and not r[rw.boss] then r[rw.boss] = {} end
        return r[rw.boss]
    end
    rw.rows = {}
    for i = 1, MAXR do
        local row = CreateFrame("Frame", nil, rw); row:SetSize(536, 22); row:SetPoint("TOPLEFT", 12, -44 - (i - 1) * 26)
        row.chan = CreateFrame("Button", nil, row); row.chan:SetSize(84, 20); bg(row.chan, 0.095, 0.105, 0.12); stroke(row.chan, HAIR, 1)
        row.chan:RegisterForClicks("LeftButtonDown"); row.chan:SetPoint("LEFT", 0, 0)
        row.chan.t = fs(row.chan, 12, TEXT); row.chan.t:SetPoint("LEFT", 8, 0)
        local a = row.chan:CreateTexture(nil, "ARTWORK"); a:SetSize(12, 12); a:SetPoint("RIGHT", -6, 0); a:SetTexture(ARROW); a:SetVertexColor(0.72, 0.75, 0.80)
        row.chan:SetScript("OnClick", function()
            local items = {}
            for _, c in ipairs(CHANNELS) do
                local v = c[2]
                items[#items + 1] = { text = c[1], color = (row.rule and row.rule.channel == v) and GOLD or TEXT, onClick = function() if row.rule then row.rule.channel = v; rw:Refresh() end end }
            end
            showMenu(items, row.chan)
        end)
        row.diff = CreateFrame("Button", nil, row); row.diff:SetSize(70, 20); bg(row.diff, 0.095, 0.105, 0.12); stroke(row.diff, HAIR, 1)
        row.diff:RegisterForClicks("LeftButtonDown"); row.diff:SetPoint("LEFT", row.chan, "RIGHT", 6, 0)
        row.diff.t = fs(row.diff, 12, TEXT); row.diff.t:SetPoint("LEFT", 8, 0)
        local da = row.diff:CreateTexture(nil, "ARTWORK"); da:SetSize(12, 12); da:SetPoint("RIGHT", -6, 0); da:SetTexture(ARROW); da:SetVertexColor(0.72, 0.75, 0.80)
        row.diff:SetScript("OnClick", function()
            local items = {}
            for _, d in ipairs(DIFFS) do
                local v = d[2]
                items[#items + 1] = { text = d[1], color = (row.rule and row.rule.diff == v) and GOLD or TEXT, onClick = function() if row.rule then row.rule.diff = v; rw:Refresh() end end }
            end
            showMenu(items, row.diff)
        end)
        -- mode dropdown: Mute during / Only during / Volume during
        row.mode = CreateFrame("Button", nil, row); row.mode:SetSize(110, 20); bg(row.mode, 0.095, 0.105, 0.12); stroke(row.mode, HAIR, 1)
        row.mode:RegisterForClicks("LeftButtonDown"); row.mode:SetPoint("LEFT", row.diff, "RIGHT", 6, 0)
        row.mode.t = fs(row.mode, 12, TEXT); row.mode.t:SetPoint("LEFT", 8, 0)
        local ma = row.mode:CreateTexture(nil, "ARTWORK"); ma:SetSize(12, 12); ma:SetPoint("RIGHT", -6, 0); ma:SetTexture(ARROW); ma:SetVertexColor(0.72, 0.75, 0.80)
        row.mode:SetScript("OnClick", function()
            local items = {}
            for _, m in ipairs(MODES) do
                local v = m[2]
                items[#items + 1] = { text = m[1], color = (row.rule and (row.rule.mode or "mute") == v) and GOLD or TEXT, onClick = function()
                    if not row.rule then return end
                    row.rule.mode = v
                    if v == "volume" and not row.rule.vol then row.rule.vol = 0 end
                    rw:Refresh()
                end }
            end
            showMenu(items, row.mode)
        end)
        -- volume % (only shown in Volume during mode)
        row.vol = makeEdit(row, 44, "%"); row.vol:SetPoint("LEFT", row.mode, "RIGHT", 6, 0)
        row.vol:SetScript("OnEnterPressed", function() row.vol:ClearFocus() end)
        row.vol:HookScript("OnEditFocusLost", function()
            if not row.rule then return end
            local n = tonumber((row.vol:GetText():gsub("[%%%s]", "")))
            if n then row.rule.vol = math.max(0, math.min(100, math.floor(n + 0.5))) / 100 end
            row.vol:SetText(("%d%%"):format(math.floor((row.rule.vol or 0) * 100 + 0.5)))
        end)
        -- hover: the channel's current (normal) volume, for reference
        row.vol:SetScript("OnEnter", function()
            if not row.rule then return end
            GameTooltip:SetOwner(row.vol, "ANCHOR_TOP")
            GameTooltip:AddLine("Volume inside the windows", GOLD[1], GOLD[2], GOLD[3])
            GameTooltip:AddLine(("Current %s volume: %d%%"):format(chanLabel(row.rule.channel), math.floor(RAS:GetChannelVolume(row.rule.channel) * 100 + 0.5)), 1, 1, 1)
            GameTooltip:Show()
        end)
        row.vol:SetScript("OnLeave", function() GameTooltip:Hide() end)
        row.win = makeEdit(row, 226, "e.g. 3:00-4:00, p2")
        local function commit()
            if not row.rule then return end
            local ws, bad = parseWindows(row.win:GetText())
            if ws then row.rule.windows = ws; row.win:SetTextColor(0.9, 0.9, 0.92); row.win:SetText(formatWindows(ws))
            else row.win:SetTextColor(RED[1], RED[2], RED[3]); print("|cffe0544eRAS:|r can't read window '" .. tostring(bad) .. "'  (use 3:00-4:00, 3:00- or p2)") end
        end
        row.win:SetScript("OnEnterPressed", function() row.win:ClearFocus() end)   -- focus loss commits
        row.win:HookScript("OnEditFocusLost", commit)
        row.del = softButton(row, "\195\151", 22, 20, function() local l = rulesList(false); if l and row.idx then table.remove(l, row.idx); rw:Refresh() end end, RED)
        row.del:SetPoint("LEFT", row.win, "RIGHT", 6, 0)
        rw.rows[i] = row
    end
    rw.add = softButton(rw, "+ add rule", 90, 20, function()
        local l = rulesList(true); if #l >= MAXR then return end
        l[#l + 1] = { channel = "Dialog", mode = "mute", windows = {} }; rw:Refresh()
    end)
    rw.add:SetPoint("BOTTOMLEFT", 8, 10)
    rw.src = fs(rw, 10, MUTED); rw.src:SetPoint("BOTTOMRIGHT", -12, 15)
    function rw:Refresh()
        local l = rulesList(false) or {}
        self.title:SetText("Channel rules:  " .. self.boss .. "  |cff6b737f(id " .. tostring(RAS.encounterIDs[self.boss]) .. ")|r")
        for i, row in ipairs(self.rows) do
            local r = l[i]; row.rule, row.idx = r, i
            if r then
                row.chan.t:SetText(chanLabel(r.channel)); row.diff.t:SetText(diffLabel(r.diff))
                row.mode.t:SetText(modeLabel(r.mode))
                -- volume box squeezes in before the windows box in Volume mode
                local isVol = r.mode == "volume"
                row.vol:SetShown(isVol)
                if isVol and not row.vol:HasFocus() then row.vol:SetText(("%d%%"):format(math.floor((r.vol or 0) * 100 + 0.5))) end
                row.win:ClearAllPoints(); row.win:SetPoint("LEFT", isVol and row.vol or row.mode, "RIGHT", 6, 0); row.win:SetWidth(isVol and 176 or 226)
                if not row.win:HasFocus() then row.win:SetTextColor(0.9, 0.9, 0.92); row.win:SetText(formatWindows(r.windows)) end
                row:Show()
            else row:Hide() end
        end
        self.add:SetShown(#l < MAXR)
        self.src:SetText("Phases from: " .. (RAS.phaseSource or "no boss mod found (time windows only)"))
        win:Refresh()   -- rules count on the button
    end
    function rw:Open(boss) self.boss = boss; self:Show(); self:Raise(); self:Refresh() end

    -- PLAYERS popup (per spell): only some raiders, or everyone except some ----
    local PMODES = { { "Everyone", nil }, { "Only these", "only" }, { "Everyone except", "except" } }
    local function pmodeLabel(v) for _, m in ipairs(PMODES) do if m[2] == v then return m[1] end end return "Everyone" end
    local PCOLS, PCW, PRH = 4, 132, 20
    local pw = CreateFrame("Frame", "HexAuraSoundsPlayers", win)
    pw:SetPoint("CENTER"); pw:SetFrameStrata("DIALOG"); pw:EnableMouse(true)
    pw:SetMovable(true); pw:RegisterForDrag("LeftButton"); pw:SetScript("OnDragStart", pw.StartMoving); pw:SetScript("OnDragStop", pw.StopMovingOrSizing)
    bg(pw, 0.06, 0.065, 0.075, 0.99); stroke(pw, GOLD, 1); pw:Hide(); win.playersWin = pw
    pw.title = fs(pw, 13, GOLD); pw.title:SetPoint("TOPLEFT", 12, -10)
    local pclose = softButton(pw, "\195\151", 34, 34, function() pw:Hide() end, MUTED); pclose:SetPoint("TOPRIGHT", -2, -2)
    do local fp = pclose.t:GetFont(); if not pclose.t:SetFont(FONT, 32, "") then pclose.t:SetFont(fp, 32, "") end end
    local function spSettings(create)
        local t = RAS.db.spellPlayers[pw.spell]
        if not t and create then t = { raiders = {} }; RAS.db.spellPlayers[pw.spell] = t end
        return t
    end
    pw.mode = CreateFrame("Button", nil, pw); pw.mode:SetSize(130, 20); bg(pw.mode, 0.095, 0.105, 0.12); stroke(pw.mode, HAIR, 1)
    pw.mode:RegisterForClicks("LeftButtonDown"); pw.mode:SetPoint("TOPLEFT", 12, -38)
    pw.mode.t = fs(pw.mode, 12, TEXT); pw.mode.t:SetPoint("LEFT", 8, 0)
    local pma = pw.mode:CreateTexture(nil, "ARTWORK"); pma:SetSize(12, 12); pma:SetPoint("RIGHT", -6, 0); pma:SetTexture(ARROW); pma:SetVertexColor(0.72, 0.75, 0.80)
    pw.mode:SetScript("OnClick", function()
        local cur = spSettings(false); cur = cur and cur.mode
        local items = {}
        for _, m in ipairs(PMODES) do
            local v = m[2]
            items[#items + 1] = { text = m[1], color = (cur == v) and GOLD or TEXT, onClick = function()
                local t = spSettings(true); t.mode = v
                if not v and not next(t.raiders) then RAS.db.spellPlayers[pw.spell] = nil end   -- back to default
                RAS:Rebuild(); pw:Refresh()
            end }
        end
        showMenu(items, pw.mode)
    end)
    pw.count = fs(pw, 11, MUTED); pw.count:SetPoint("LEFT", pw.mode, "RIGHT", 10, 0)
    pw.cells = {}
    local function getCell(i)
        local c = pw.cells[i]; if c then return c end
        c = CreateFrame("Button", nil, pw); c:SetSize(PCW - 4, PRH); c:RegisterForClicks("LeftButtonDown")
        c.hl = c:CreateTexture(nil, "BACKGROUND"); c.hl:SetAllPoints(); c.hl:SetColorTexture(1, 1, 1, 0)
        c.box = CreateFrame("Frame", nil, c); c.box:SetSize(11, 11); c.box:SetPoint("LEFT", 4, 0); stroke(c.box, HAIR, 1)
        c.box.fill = c.box:CreateTexture(nil, "ARTWORK"); c.box.fill:SetPoint("TOPLEFT", 1, -1); c.box.fill:SetPoint("BOTTOMRIGHT", -1, 1)
        c.t = fs(c, 12, TEXT); c.t:SetPoint("LEFT", c.box, "RIGHT", 6, 0)
        c:SetScript("OnEnter", function() c.hl:SetColorTexture(1, 1, 1, 0.05) end)
        c:SetScript("OnLeave", function() c.hl:SetColorTexture(1, 1, 1, 0) end)
        c:SetScript("OnClick", function()
            local t = spSettings(false); if not (t and t.mode) then return end
            t.raiders[c.raider] = (not t.raiders[c.raider]) or nil
            RAS:Rebuild(); pw:Refresh()
        end)
        pw.cells[i] = c; return c
    end
    pw.clear = softButton(pw, "clear", 50, 20, function()
        local t = spSettings(false); if t then wipe(t.raiders); RAS:Rebuild(); pw:Refresh() end
    end, MUTED)
    pw.clear:SetPoint("BOTTOMLEFT", 8, 10)
    function pw:Refresh()
        local t = spSettings(false); local mode = t and t.mode
        local sid, idx = RAS.EntrySpell(self.spell), RAS.EntryIndex(self.spell)
        local nm = (C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(sid)) or ("Spell " .. sid)
        self.title:SetText("Players:  " .. nm .. (idx > 1 and (" #" .. idx) or "") .. "  |cff6b737f(" .. sid .. ")|r")
        self.mode.t:SetText(pmodeLabel(mode))
        local n = 0
        for i, r in ipairs(RAS.playerOrder) do
            local c = getCell(i); c.raider = r
            c:ClearAllPoints(); c:SetPoint("TOPLEFT", 12 + ((i - 1) % PCOLS) * PCW, -68 - math.floor((i - 1) / PCOLS) * PRH)
            local on = t and t.raiders[r]
            if on then n = n + 1 end
            local col = on and (mode == "except" and RED or GREEN)
            if col then c.box.fill:SetColorTexture(col[1], col[2], col[3], 0.9) else c.box.fill:SetColorTexture(0.16, 0.17, 0.19, 1) end
            c.t:SetText(r); c:SetAlpha(mode and 1 or 0.4); c:EnableMouse(mode ~= nil)
            c:Show()
        end
        for i = #RAS.playerOrder + 1, #self.cells do self.cells[i]:Hide() end
        if mode == "only" then self.count:SetText(n .. " selected: only they get this spell's sound")
        elseif mode == "except" then self.count:SetText(n .. " selected: they don't get this spell's sound")
        else self.count:SetText("every raider gets this spell's sound") end
        self.clear:SetShown(mode ~= nil)
        local rows = math.max(1, math.ceil(#RAS.playerOrder / PCOLS))
        self:SetSize(24 + PCOLS * PCW, 68 + rows * PRH + 44)
        win:Refresh()   -- the spell's "P" tag
    end
    function pw:Open(id) self.spell = id; self:Show(); self:Raise(); self:Refresh() end

    -- light blue, on the "+ add" row
    local rulesBtn = softButton(win, "Boss rules", 100, 20, function()
        local _, sn = RAS:Selected()
        if rw:IsShown() and rw.boss == sn then rw:Hide() else rw:Open(sn) end
    end, BLUE)
    rulesBtn:SetPoint("LEFT", addBtn, "RIGHT", 12, 0); win.rulesBtn = rulesBtn

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
        self.sw:refresh(); if self.scaleSlider then self.scaleSlider:SyncValue() end; self:SyncChannel()
        -- spell selection + tier highlight
        local st, sn = RAS:Selected()
        self.spellSub:SetText(sn ~= "" and sn or "")
        -- channel rules: raid bosses with an encounter ID only
        local ruled = st == "raid" and RAS.encounterIDs ~= nil and RAS.encounterIDs[sn] ~= nil
        local rl = RAS.db.rules[sn]
        self.rulesBtn:SetShown(ruled); self.rulesBtn.t:SetText((rl and #rl > 0) and ("Boss rules (" .. #rl .. ")") or "Boss rules")
        if self.rulesWin:IsShown() and self.rulesWin.boss ~= sn then
            if ruled then self.rulesWin:Open(sn) else self.rulesWin:Hide() end
        end
        for _, b in ipairs(self.tier1 or {}) do local seld = b.tier == st; b.selbg:SetShown(seld); b.bar:SetShown(seld); b.gdot:SetShown(RAS:TierHasEnabled(b.tier)) end
        self:LayoutTier2()
        for _, b in ipairs(self.t2pool or {}) do local seld = b:IsShown() and b.name == sn; b.selbg:SetShown(seld); b.bar:SetShown(seld) end
        -- spells for the selected group
        local spells = RAS:GroupTracked(st, sn); self.sCount:SetText(#spells)
        local slist, needLoad = {}, false
        -- id = entry key (settings), sid = the spell itself (name, icon, tooltip)
        for _, s in ipairs(spells) do
            local sid = RAS.EntrySpell(s)
            slist[#slist + 1] = { id = s, sid = sid }
            if C_Spell and C_Spell.GetSpellName and not C_Spell.GetSpellName(sid) then needLoad = true; if C_Spell.RequestLoadSpellData then C_Spell.RequestLoadSpellData(sid) end end
        end
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