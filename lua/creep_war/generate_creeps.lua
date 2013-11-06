<<

local function generate_one(score, data)
    local alignment = cc.weighted_choice {
        { 40, 'chaotic' },
        { 40, 'lawful' },
        { 20, 'neutral' }
    }

    local role = cc.weighted_choice {
        { 25, 'mixed fighter' },
        { 25, 'fighter' },
        { 25, 'ranger' },
        { 15, 'scout' },
        { 10, 'healer' }
    }

    local level

    if score < 10 then
        level = 0
    elseif score < 20 then
        level = cc.choice { 0, 1 }
    elseif score < 30 then
        level = 1
    elseif score < 50 then
        level = cc.choice { 1, 2 }
    elseif score < 100 then
        level = 2
    elseif score < 150 then
        level = cc.choice { 2, 3 }
    elseif score < 250 then
        level = 3
    elseif score < 350 then
        level = cc.weighted_choice { { 75, 3 }, { 25, 4} }
    else
        level = cc.weighted_choice { { 60, 3 }, { 20, 4}, { 20, 5} }
    end

    local available = cc.intersect {
        cc.units_by_alignment[alignment],
        cc.units_by_level[level],
        cc.units_by_role[role]
    }

    if #available == 0 then
        -- if the conditions are unsatisfiable, generate at least something
        available = cc.units_by_level[level]
    end

    return cc.choice(cc.keys(available))
end

function wesnoth.wml_actions.cw_generate_creeps(cfg_raw)
    local cfg = cfg_raw.__parsed

    local score = cfg.score
    local count = cfg.count
    local variable = cfg.variable
    local key = cfg.key
    local data = {}

    local function choice()
        local units = {}
    
        for i = 1, count do
            table.insert(units, generate_one(score, data))
        end

        return { value = table.concat(units, '#') }
    end
    
    local result = wesnoth.synchronize_choice(choice, choice)

    local n = 0
    for id in string.gmatch(result.value, "[^#]+") do
        wesnoth.fire("set_variable", {
            name = variable .. "[" .. tostring(n) .. "]." .. key,
            value = id
        })
        n = n + 1
    end
end

>>
