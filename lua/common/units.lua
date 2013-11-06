<<

cc.units = {}
cc.units_by_level = {}
cc.units_by_alignment = {}
cc.units_by_role = {}

local function add_to_category(category, place, unit)
    if place == nil then
        return
    end

    if category[place] == nil then
        category[place] = {}
    end

    category[place][unit.id] = unit
end

local function build()
    for id,unit_type in pairs(wesnoth.unit_types) do
        local cfg = unit_type.__cfg

        local unit = {
            id = id,
            name = unit_type.name,
            cost = unit_type.cost,
            level = unit_type.level,
            alignment = cfg.alignment,
            role = cfg.role,
            max_hitpoints = unit_type.max_hitpoints,
            max_moves = unit_type.max_moves,
            max_experience = unit_type.max_experience,
            cfg = cfg
        }

        add_to_category(cc.units_by_level,     unit.level,     unit)
        add_to_category(cc.units_by_alignment, unit.alignment, unit)
        add_to_category(cc.units_by_role,      unit.role,      unit)
    end 
end

build()

>>
