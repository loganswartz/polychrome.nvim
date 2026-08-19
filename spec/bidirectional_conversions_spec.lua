local name_mappings = {
    ciexyz = "xyz",
}

---@class GenerateCasesOpts
---@field spaces string[]?
---@field rgb_values ([number, number, number][])?

---@param opts GenerateCasesOpts?
---@return {[string]: number[]}[]?
local function generate_cases(opts)
    opts = opts or {}

    opts.spaces = opts.spaces or vim.tbl_keys(require("polychrome.color"))
    opts.rgb_values = opts.rgb_values
        or {
            { 0, 0, 0 },
            { 128, 128, 128 },
            { 255, 255, 255 },
            { 255, 0, 0 },
            { 0, 255, 0 },
            { 0, 0, 255 },
            { 128, 128, 0 },
            { 128, 0, 128 },
            { 0, 128, 128 },
        }

    for idx, space in ipairs(opts.spaces) do
        if name_mappings[space] ~= nil then
            opts.spaces[idx] = name_mappings[space]
        end
    end

    -- Get the global npm prefix
    local npm = vim.system({ "npm", "-g", "prefix" }, { text = true }):wait()
    assert(npm.code == 0, ("should be able to get npm prefix:\n%s"):format(npm.stderr))
    local npm_prefix = vim.trim(npm.stdout)

    -- Generate test cases directly from color-space.io data
    local script = ([[
    async function run() {
        const data = %s;

        const { default: space } = await import("%s/lib/node_modules/color-space/index.js");

        const results = [];

        for (const values of data.rgb_values) {
            const obj = {};
            for (const s of data.spaces) {
                obj[s] = space.rgb[s](...values);
            }
            results.push(obj);
        }

        console.log(JSON.stringify(results))
    }

    run();
    ]]):format(vim.json.encode(opts), npm_prefix)

    local cmd = vim.system({ "node", "-" }, { text = true, stdin = true })
    cmd:write({ script })
    cmd:write(nil)
    local result = cmd:wait()

    assert(result.code == 0, ("should be able to load test cases:\n%s"):format(result.stderr))

    local decoded = vim.json.decode(result.stdout)
    assert(decoded, "should be able to decode test cases")

    for _, case in ipairs(decoded) do
        for polychrome_key, colorspace_key in pairs(name_mappings) do
            if case[colorspace_key] ~= nil then
                case[polychrome_key] = case[colorspace_key]
                case[colorspace_key] = nil
            end
        end
    end

    return decoded
end

describe("bi-directional color conversion", function()
    local cases = generate_cases() or {}

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
