-- Read by: WezTerm, as the SYSTEM-WIDE default configuration.
--
-- WezTerm looks for its config in this order, first file that exists wins
-- (config/src/config.rs, load_with_overrides):
--
--   1. $WEZTERM_CONFIG_FILE          (not set by this image — see below)
--   2. ~/.wezterm.lua
--   3. $XDG_CONFIG_HOME/wezterm/wezterm.lua, defaulting to ~/.config/wezterm/wezterm.lua
--   4. <dir>/wezterm/wezterm.lua      for each entry of $XDG_CONFIG_DIRS
--
-- This file is reached by (4), so a user's own config at (2) or (3) shadows it wholesale
-- with nothing to undo — the same relationship fastfetch and zellij have (DD-031, DD-033).
-- WEZTERM_CONFIG_FILE would have been the obvious lever and is deliberately NOT used: it
-- is inserted at the FRONT of that list, so it would beat the user rather than lose to
-- them.
--
-- $XDG_CONFIG_DIRS IS LOAD-BEARING HERE. WezTerm reads the variable and does not fall back
-- to the spec's /etc/xdg default when it is unset, so if nothing sets it this file is never
-- looked at. /usr/lib/environment.d/50-qubix-terminal.conf guarantees it.
--
-- Colour schemes are found the same way: `compute_color_scheme_dirs()` appends `colors/` to
-- each of those directories, so colors/*.toml beside this file is where "Oxocarbon Dark"
-- below comes from — and those schemes stay available even to a user whose own wezterm.lua
-- has replaced this file.
--
-- See docs/desktops.md and docs/design-decisions.md DD-012, DD-034.

local wezterm = require("wezterm")

local config = wezterm.config_builder()

-- ── Fonts ─────────────────────────────────────────────────────────────────────
-- A fallback chain: WezTerm takes each glyph from the first family that has it.
--
-- Monaspace Krypton NF and IBM Plex Math are not packaged by Fedora and are installed from
-- upstream by a build step in recipes/common-base.yml; IBM Plex Mono and Sans are the
-- ibm-plex-*-fonts RPMs. The build ASSERTS that WezTerm resolves every family named here,
-- so a font that stops being installed fails CI rather than silently rendering as boxes.
--
-- CJK IS NOTO, NOT PLEX. IBM ships Plex Sans SC/TC/JP only as ~1.2 GB of release archives
-- that Fedora does not package; google-noto-sans-cjk-fonts covers the same three scripts
-- and is one dnf line. The order — Simplified, then Traditional, then Japanese — is what
-- decides which regional form a shared Han character is drawn in, so it is kept.
--
-- No Nerd Font entry is needed: WezTerm bundles Symbols Nerd Font Mono as a built-in
-- fallback, after everything named here (DD-012).
config.font = wezterm.font_with_fallback({
	"Monaspace Krypton NF",
	"IBM Plex Math",
	"IBM Plex Mono",
	"IBM Plex Sans",
	"Noto Sans CJK SC",
	"Noto Sans CJK TC",
	"Noto Sans CJK JP",
})

-- ── Colours ───────────────────────────────────────────────────────────────────
-- Both named schemes are shipped in colors/ beside this file. The name is the scheme
-- file's `[metadata] name`, not its filename. "Catppuccin Mocha" is one of WezTerm's
-- builtins and needs no file.
-- config.color_scheme = "Catppuccin Mocha"
-- config.color_scheme = "SuperuserKAM"
config.color_scheme = "Oxocarbon Dark"

-- ── Window and tabs ───────────────────────────────────────────────────────────
-- "RESIZE" means no title bar, resize borders only — intended, and what makes the window
-- look the same in Plasma and in Niri.
config.use_fancy_tab_bar = false
config.window_decorations = "RESIZE"
config.hide_tab_bar_if_only_one_tab = true

-- TRANSPARENT, AND NOT BLURRED. There is no Wayland equivalent of the macOS blur this
-- setting is normally paired with: WezTerm never asks for a blurred background region, so
-- KWin's blur effect does not apply to it and Niri has no blur at all. What is behind the
-- window shows through at full detail. Set this to 1.0 for an opaque window.
config.window_background_opacity = 0.75

return config
