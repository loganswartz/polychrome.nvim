describe("bi-directional color conversion", function()
    local cases = {
        {
            rgb = { 0, 0, 0 },
            lrgb = { 0, 0, 0 },
            hsl = { 0, 0, 0 },
            oklab = { 0, 0, 0 },
            oklch = { 0, 0, 0 },
            ciexyz = { 0, 0, 0 },
            lms = { 0, 0, 0 },
        },
        {
            rgb = { 255, 255, 255 },
            lrgb = { 1, 1, 1 },
            hsl = { 0, 0, 100 },
            oklab = { 1, 0, 0 },
            oklch = { 1, 0, 0 },
            ciexyz = { 95, 100, 109 },
            lms = { 95, 104, 109 },
        },
        {
            rgb = { 255, 0, 0 },
            lrgb = { 1.0, 0, 0 },
            hsl = { 0, 100, 50 },
            oklab = { 0.628, 0.225, 0.126 },
            oklch = { 0.628, 0.2577, 29.23 },
            ciexyz = { 41.2, 21, 2 },
            lms = { 39, 7, 2 },
        },
    }

    local colorspaces = require("polychrome.color")

    for _, case in ipairs(cases) do
        for name, values in pairs(case) do
            local color = colorspaces[name]:new(values)

            for other, other_values in pairs(case) do
                it(("from %s to %s"):format(name, other), function()
                    assert.equal(colorspaces[other]:new(other_values), color:to(other))
                end)
            end
        end
    end
end)
