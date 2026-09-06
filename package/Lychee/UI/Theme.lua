local Lychee = _G.Lychee or {}
_G.Lychee = Lychee
Lychee.UI = Lychee.UI or {}

local Theme = {}

-- Canonical tokens are immutable by convention. Their table identity is also
-- used as the native-setter cache key, so callers should reference, not copy.
Theme.Colors = {
    window = { 0.035, 0.037, 0.043, 0.985 },
    header = { 0.055, 0.057, 0.065, 1 },
    content = { 0.043, 0.045, 0.052, 1 },
    footer = { 0.032, 0.034, 0.040, 1 },
    surface = { 0.075, 0.078, 0.088, 1 },
    surfaceHover = { 0.105, 0.108, 0.120, 1 },
    surfaceSelected = { 0.135, 0.090, 0.098, 1 },
    input = { 0.028, 0.030, 0.036, 1 },
    inputHover = { 0.040, 0.042, 0.050, 1 },
    inputFocus = { 0.050, 0.046, 0.052, 1 },
    action = { 0.075, 0.078, 0.088, 1 },
    actionHover = { 0.175, 0.115, 0.125, 1 },
    border = { 0.165, 0.170, 0.188, 1 },
    borderStrong = { 0.285, 0.290, 0.315, 1 },
    accent = { 0.835, 0.235, 0.285, 1 },
    accentMuted = { 0.440, 0.155, 0.185, 1 },
    text = { 0.940, 0.932, 0.910, 1 },
    textMuted = { 0.710, 0.705, 0.690, 1 },
    textDim = { 0.500, 0.500, 0.500, 1 },
    disabled = { 0.315, 0.315, 0.325, 1 },
    success = { 0.310, 0.690, 0.455, 1 },
    warning = { 0.880, 0.645, 0.250, 1 },
    danger = { 0.895, 0.300, 0.315, 1 },
}

Theme.Metrics = {
    paletteWidth = 720,
    paletteHeight = 500,
    headerHeight = 76,
    footerHeight = 28,
    contentPadding = 16,
    inputHeight = 44,
    resultColumns = 4,
    resultTiles = 12,
    resultTileWidth = 156,
    rowHeight = 72,
    rowGap = 8,
    resultPadding = 20,
    paletteMinHeight = 220,
    paletteMaxHeight = 500,
    iconSize = 32,
    border = 1,
}

Theme.Spacing = {
    tight = 6,
    control = 10,
    content = 16,
    section = 24,
}

Theme.Sizes = {
    paletteWidth = Theme.Metrics.paletteWidth,
    paletteHeight = Theme.Metrics.paletteHeight,
    headerHeight = Theme.Metrics.headerHeight,
    footerHeight = Theme.Metrics.footerHeight,
    inputHeight = Theme.Metrics.inputHeight,
    rowHeight = Theme.Metrics.rowHeight,
    action = Theme.Metrics.actionSize,
}

local function resolveColor(color)
    if type(color) == "string" then return Theme.Colors[color] end
    return color
end

function Theme:GetColor(name)
    return self.Colors[name] or self.Colors.text
end

function Theme:SetColorTexture(texture, color)
    color = resolveColor(color)
    if not texture or type(texture.SetColorTexture) ~= "function" or not color or texture._lycheeColorToken == color then return false end
    texture:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
    texture._lycheeColorToken = color
    return true
end

function Theme:SetVertexColor(texture, color)
    color = resolveColor(color)
    if not texture or type(texture.SetVertexColor) ~= "function" or not color or texture._lycheeVertexToken == color then return false end
    texture:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
    texture._lycheeVertexToken = color
    return true
end

function Theme:SetTextColor(fontString, color)
    color = resolveColor(color)
    if not fontString or type(fontString.SetTextColor) ~= "function" or not color or fontString._lycheeTextToken == color then return false end
    fontString:SetTextColor(color[1], color[2], color[3], color[4] or 1)
    fontString._lycheeTextToken = color
    return true
end

function Theme:SetAlpha(region, alpha)
    if not region or type(region.SetAlpha) ~= "function" or region._lycheeAlpha == alpha then return false end
    region:SetAlpha(alpha)
    region._lycheeAlpha = alpha
    return true
end

function Theme:SetShown(region, shown)
    shown = shown == true
    if not region or type(region.IsShown) ~= "function" then return false end
    if region:IsShown() == shown then return false end
    region:SetShown(shown)
    return true
end

function Theme:CreateSurface(frame, backgroundColor, borderColor)
    if frame._lycheeSurface then return frame._lycheeSurface end
    local surface = {
        background = frame:CreateTexture(nil, "BACKGROUND", nil, -2),
        border = {},
    }
    surface.background:SetAllPoints(frame)
    local thickness = self.Metrics.border
    local anchors = {
        { "TOPLEFT", "TOPRIGHT", 0, 0, 0, -thickness },
        { "BOTTOMLEFT", "BOTTOMRIGHT", 0, thickness, 0, 0 },
        { "TOPLEFT", "BOTTOMLEFT", 0, -thickness, thickness, 0 },
        { "TOPRIGHT", "BOTTOMRIGHT", -thickness, -thickness, 0, 0 },
    }
    for index = 1, 4 do
        local edge = frame:CreateTexture(nil, "BORDER", nil, -1)
        local anchor = anchors[index]
        edge:SetPoint(anchor[1], frame, anchor[1], anchor[3], anchor[4])
        edge:SetPoint(anchor[2], frame, anchor[2], anchor[5], anchor[6])
        surface.border[index] = edge
    end
    frame._lycheeSurface = surface
    self:ApplySurface(frame, backgroundColor, borderColor)
    return surface
end

function Theme:ApplySurface(frame, backgroundColor, borderColor)
    local surface = frame and frame._lycheeSurface
    if not surface then return false end
    local changed = self:SetColorTexture(surface.background, backgroundColor)
    for index = 1, #surface.border do
        if self:SetColorTexture(surface.border[index], borderColor) then changed = true end
    end
    return changed
end

Lychee.UI.Theme = Theme
