Config = {}
Config.Models = { base = 'mri_dichavador_base', tampa = 'mri_dichavador_tampa' }
-- Both drawables share the center of the CLOSED grinder as their origin.
-- Dimensions: diameter 0.070 m, closed height 0.028 m. No scaling required.
-- Initial hand offsets: adjust for the ped and animation used by your inventory.
Config.Closed = {
    bone = 57005, -- SKEL_R_Hand
    pos = { 0.075, 0.025, -0.010 },
    rot = { 0.0, 90.0, 0.0 }
}
Config.Open = {
    base = { bone = 18905, pos = { 0.075, 0.025, 0.010 }, rot = { 0.0, -90.0, 0.0 } },
    tampa = { bone = 57005, pos = { 0.075, 0.025, -0.010 }, rot = { 180.0, 90.0, 0.0 } }
}
