-- aptus: Hyprland's colours and flags (08-theming §8), written by aptus-theme (generation
-- {{ generation }}) and loaded by hypr/init.lua. Do not edit: the next render replaces it.
return {
  ground = "rgb({{ ground | hexnoh }})",
  line = "rgb({{ line | hexnoh }})",
  accent = "rgb({{ accent | hexnoh }})",
  shadow = "{{ shadow | hyprrgba(shadowAlpha) }}",
  frame_edge = {{ frame.edge }},
  window_gap = {{ window.gap }},
  glass = {{ glass }},
  reduce_motion = {{ reduce_motion }},
}
