local utils = require("polychrome.utils")

describe("cartesian distance calculations", function()
    local cases = {
        {
            a = { 0 },
            b = { 1 },
            scales = nil,
            result = 1,
        },
        {
            a = { 0 },
            b = { 2 },
            scales = { 2 },
            result = 1,
        },
        {
            a = { 0, 0 },
            b = { 1, 1 },
            scales = nil,
            result = math.sqrt(2),
        },
        {
            a = { 0, 0 },
            b = { 3, 4 },
            scales = nil,
            result = 5,
        },
        {
            a = { 0, 0, 0 },
            b = { 0, 1, 1 },
            scales = nil,
            result = math.sqrt(2),
        },
        {
            a = { 0, 0, 0 },
            b = { 0, 3, 4 },
            scales = nil,
            result = 5,
        },
        {
            a = { 0, 0, 0 },
            b = { 1, 1, 1 },
            scales = nil,
            result = math.sqrt(3),
        },
        {
            a = { 0, 0, 0 },
            b = { 0, 3, 4 * 2 },
            scales = { 1, 1, 2 },
            result = 5,
        },
        {
            a = { 0, 0, 0 },
            b = { 0, 3, 4 },
            scales = { 1, 3, 4 },
            result = math.sqrt(2),
        },
        {
            a = { 0, 0, 0 },
            b = { 1, 3, 4 },
            scales = { 1, 3, 4 },
            result = math.sqrt(3),
        },
    }

    for _, case in ipairs(cases) do
        it(("should have the right distance"):format(case.result), function()
            assert.equal(case.result, utils.cartesian_distance(case.a, case.b, case.scales))
        end)
    end
end)
