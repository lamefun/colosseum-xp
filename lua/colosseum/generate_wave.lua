<<

local function get_range(cfg, name)
    local min = cfg["min_" .. name]
    local max = cfg["max_" .. name]
    local exact = cfg[name]

    if exact ~= nil then
        return { min = exact, max = exact }
    else
        return { min = min, max = max }
    end
end

local function match_range(range, num)
    if range == nil then
        return true
    end

    local min = range.min
    local max = range.max

    return (min == nil or num >= min) and (max == nil or num <= max)
end

local function parse_group(cfg)
    return {
        count = get_range(cfg, "count"),
        level = get_range(cfg, "level"),
        moves = get_range(cfg, "moves"),
        hitpoints = get_range(cfg, "hitpoints"),
        experience = get_range(cfg, "experience")
    }
end

local function filter_unit_type(name, group)
    local ut = wesnoth.unit_types[name]
    local uc = ut.__cfg.__parsed

    if match_range(group.level, ut.level) and
       match_range(group.moves, ut.max_moves) and
       match_range(group.hitpoints, ut.max_hitpoints) and
       match_range(group.experience, ut.max_experience) and
       (group.role == nil or uc.role == group.role) then
        return true
    else
        return false
    end
end

local function generate_wave(desc)
    local group_sizes = {}
    local unit_count = 0

    for i,group in ipairs(desc.groups) do
        if group.count.min ~= nil then
            group_sizes[i] = group.count.min
            unit_count = unit_count + group.count.min
        else
            group_sizes[i] = 0
        end
    end

    local not_maxed_groups = {}

    while true do
        not_maxed_groups = {}
        for i,group in ipairs(desc.groups) do
            if group.count.max == nil or group_sizes[i] < group.count.max then
                table.insert(not_maxed_groups, i)
            end
        end

        if unit_count == desc.count or #not_maxed_groups == 0 then
            break
        end

        local extend_i = cc.choice(not_maxed_groups)
        group_sizes[extend_i] = group_sizes[extend_i] + 1
        unit_count = unit_count + 1
    end

    local possible_units = {}

    for i,group in ipairs(desc.groups) do
        possible_units[i] = {}
        for name,v in pairs(wesnoth.unit_types) do
            if filter_unit_type(name, group) then
                table.insert(possible_units[i], name)
            end
        end
    end

    local units = {}

    for i,group in ipairs(desc.groups) do
        local possible = possible_units[i]
        for j = 1,group_sizes[i] do
            table.insert(units, cc.choice(possible))
        end
    end

    return units
end

function wesnoth.wml_actions.cs_generate_wave(cfg_raw)
    local cfg = cfg_raw.__parsed

    local desc = {
        count = cfg.count,
        groups = {}
    }

    for i,tag in ipairs(cfg) do
        if tag[1] == "group" then
            table.insert(desc.groups, parse_group(tag[2]))
        end
    end

    local result = wesnoth.synchronize_choice(function()
        return { value = table.concat(generate_wave(desc), "#") }
    end, function()
        return { value = table.concat(generate_wave(desc), "#") }
    end)

    local n = 0
    for name in string.gmatch(result.value, "[^#]+") do
        wesnoth.fire("set_variable", {
            name = cfg.variable .. "[" .. tostring(n) .. "]." .. cfg.key,
            value = name
        })
        n = n + 1
    end
end

>>
