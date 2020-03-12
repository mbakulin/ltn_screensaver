data:extend({
    {
        type = "int-setting",
        name = "ltn-scr-transition-time",
        localised_name = "Transition time",
        localised_description = "Determines number of ticks it takes to pan camera to the next train. Set to 0 for immediate transfers.",
        setting_type = "runtime-per-user",
        default_value = 300,
        minimum_value = 0
    },
    {
        type = "int-setting",
        name = "ltn-scr-delivery-history-size",
        localised_name = "Delivery history size",
        localised_description = "If an item was delivered in one of previous <value> deliveries, it won't be shown again. Set to 0 to disable.",
        setting_type = "runtime-per-user",
        default_value = 10,
        minimum_value = 0
    },
    {
        type = "bool-setting",
        name = "ltn-scr-reset-history",
        localised_name = "Reset delivery history",
        localised_description = "Clear delivery history when screensaver is turned off",
        setting_type = "runtime-per-user",
        default_value = false
    }
})