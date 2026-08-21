local ADDON, RAS = ...

-- ============================================================================
-- BOSSES / DUNGEONS  (spell-list categories)
-- ----------------------------------------------------------------------------
-- The spell UI groups spells under Raid bosses, Mythic+ dungeons, and 5 Custom
-- slots. List them here in order; the button label is auto-derived from the
-- capital letters in the name ("Nek'zali the Soulcoiler" -> "NS",
-- "Temple of Sethraliss" -> "TS"). Add/remove entries and the buttons re-space
-- themselves. Icons are optional and set in RAS.icons below (fill in later).
--
-- Note: which group a spell sits in is only for organizing the UI. Every enabled
-- spell in every group is always registered, so sounds play no matter which
-- group is currently shown.
-- ============================================================================

RAS.raid = {
    "Nek'zali the Soulcoiler",
    "Entombed Sentinels",
    "The Lost Explorers",
    "Vashnik the Malignant",
    "SSZorak",
    "The Twin Fangs",
    "The Coiled Altar",
    "Ula'Tek",
    "Nymrissa Wavecaller",
}

RAS.mplus = {
    "Temple of Sethraliss",
    "Murder Row",
    "Den of Nalorakk",
    "Blinding Vale",
    "Voidscar Arena",
    "Altar of Fangs",
    "Ruby Life Pools",
    "King's Rest",
    -- add the rest of the dungeons...
}

-- Optional icons, keyed by exact boss/dungeon name. Values are in-game icon
-- FileDataIDs (numbers), e.g. Temple of Sethraliss = 2011143. Missing = default.
RAS.icons = {
    ["Temple of Sethraliss"] = 2011143,
    ["Murder Row"] = 7266213,
    ["Den of Nalorakk"] = 7266214,
    ["Blinding Vale"] = 7354408,
    ["Voidscar Arena"] = 7439626,
    ["Altar of Fangs"] = 7956175,
    ["Ruby Life Pools"] = 4578416,
    ["King's Rest"] = 2011123,    
    ["Nek'zali the Soulcoiler"] = 7966621,
    ["Entombed Sentinels"] = 7966620,
    ["The Lost Explorers"] = 7966622,
    ["Vashnik the Malignant"] = 7966618,
    ["SSZorak"] = 7966619,
    ["The Twin Fangs"] = 7966623,
    ["The Coiled Altar"] = 7966625,
    ["Ula'Tek"] = 7966624,
    ["Nymrissa Wavecaller"] = 3012069,
}