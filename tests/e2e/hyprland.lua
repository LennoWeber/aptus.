-- The nested Hyprland's config (07 §13). nested.py copies this file to <tmp>/cfg/hyprland.lua
-- beside an aptus → <repo>/hypr link (nothing in the repo), with HOME the temporary home.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })
hl.config({ input = { kb_layout = "de" } })

-- >>> aptus >>>
require("aptus.init")
-- <<< aptus <<<
