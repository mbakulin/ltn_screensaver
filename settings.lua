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
        type = "double-setting",
        name = "ltn-scr-transition-zoom-multiplier",
        localised_name = "Transition zoom multiplier",
        localised_description = "During the transition to the next train, zoom will gradually change by <value> multiplier. Higher",
        setting_type = "runtime-per-user",
        default_value = 1,
        minimum_value = 0
    }
})