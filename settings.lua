data:extend({
    {
        type = "int-setting",
        name = "ltn-scr-transition-time",
        localised_name = {"transition-time"},
        localised_description = {"transition-time-description"},
        setting_type = "runtime-per-user",
        default_value = 300,
        minimum_value = 0
    },
    {
        type = "int-setting",
        name = "ltn-scr-locomotive-transition-time",
        localised_name = {"locomotive-transition-time"},
        localised_description = {"locomotive-transition-time-description"},
        setting_type = "runtime-per-user",
        default_value = 15,
        minimum_value = 0
    },
    {
        type = "int-setting",
        name = "ltn-scr-delivery-history-size",
        localised_name = {"delivery-history-size"},
        localised_description = {"delivery-history-size-description"},
        setting_type = "runtime-per-user",
        default_value = 10,
        minimum_value = 0
    },
    {
        type = "bool-setting",
        name = "ltn-scr-reset-history",
        localised_name = {"reset-delivery-history"},
        localised_description = {"reset-delivery-history-description"},
        setting_type = "runtime-per-user",
        default_value = false
    },
    {
        type = "bool-setting",
        name = "ltn-scr-debug-output",
        localised_name = {"debug-output"},
        setting_type = "runtime-global",
        default_value = false
    }
})