-- aptus: window rules. Scaffold only. Blur is requested by the shell itself (BackgroundEffect), so there are NO layer rules for blur.
--
-- TODO(phase 7): hl.window_rule float + size for the settings window and the confirmation dialog.
-- TODO(phase 7): optional: layer rule no_anim for namespaces 'aptus-*' (the shell animates itself).
-- TODO(phase 7): idle inhibit for fullscreen windows is handled by Idle.fullscreenInhibit, not by a rule here.
return {}
