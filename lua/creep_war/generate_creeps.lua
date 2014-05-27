<<

local helper = wesnoth.require "lua/helper.lua"

local unit_cfg_cache = {}

local unit_ids = {
    "Ghost",
    "Ghoul",
    "Giant Mudcrawler",
    "Giant Rat",
    "Giant Scorpion",
    "Giant Spider", 
    "Goblin Impaler",
    "Goblin Knight",
    "Goblin Pillager",
    "Goblin Rouser",
    "Goblin Spearman",
    "Grand Knight",
    "Grand Marshal",
    "Great Mage",
    "Great Troll",
    "Great Wolf",
    "Gryphon",
    "Gryphon Master",
    "Gryphon Rider",
    "Halberdier",
    "Heavy Infantryman",
    "Highwayman",
    "Horseman",
    "Huntsman",
    "Hurricane Drake",
    "Inferno Drake",
    "Iron Mauler",
    "Javelineer",
    "Knight",
    "Lancer",
    "Lich",
    "Lieutenant",
    "Longbowman",
    "Mage",
    "Mage of Light",
    "Master at Arms",
    "Master Bowman",
    "Mermaid Diviner",
    "Mermaid Enchantress",
    "Mermaid Initiate",
    "Mermaid Priestess",
    "Mermaid Siren",
    "Merman Entangler",
    "Merman Fighter",
    "Merman Hoplite",
    "Merman Hunter",
    "Merman Javelineer",
    "Merman Netcaster",
    "Merman Spearman",
    "Merman Triton",
    "Merman Warrior",
    "Mudcrawler",
    "Naga Fighter",
    "Naga Myrmidon",
    "Naga Warrior",
    "Necromancer",
    "Necrophage",
    "Nightgaunt",
    "Ogre",
    "Orcish Archer",
    "Orcish Assassin",
    "Orcish Crossbowman",
    "Orcish Grunt",
    "Orcish Leader",
    "Orcish Ruler",
    "Orcish Slayer",
    "Orcish Slurbow",
    "Orcish Sovereign",
    "Orcish Warlord",
    "Orcish Warrior",
    "Outlaw",
    "Paladin",
    "Peasant",
    "Pikeman",
    "Poacher",
    "Ranger",
    "Red Mage",
    "Revenant",
    "Rogue",
    "Royal Guard",
    "Royal Warrior",
    "Ruffian",
    "Saurian Ambusher",
    "Saurian Augur",
    "Saurian Flanker",
    "Saurian Oracle",
    "Saurian Skirmisher",
    "Saurian Soothsayer",
    "Sea Serpent",
    "Sergeant",
    "Shadow",
    "Shock Trooper",
    "Silver Mage",
    "Skeletal Dragon",
    "Skeleton",
    "Skeleton Archer",
    "Sky Drake",
    "Soulless",
    "Spearman",
    "Spectre",
    "Swordsman",
    "Thief",
    "Thug",
    "Trapper",
    "Troll",
    "Troll Hero",
    "Troll Rocklobber",
    "Troll Shaman",
    "Troll Warrior",
    "Troll Whelp",
    "Vampire Bat",
    "Walking Corpse",
    "Water Serpent",
    "White Mage",
    "Wolf",
    "Wolf Rider",
    "Woodsman",
    "Wose",
    "Wraith",
    "Yeti",
    "Young Ogre"
}

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

    if score < 20 then
        level = 0
    elseif score < 30 then
        level = cc.choice { 0, 1 }
    elseif score < 60 then
        level = 1
    elseif score < 80 then
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

    local available = {}
    local level_available = {}

    for i,id in ipairs(unit_ids) do
        ut = wesnoth.unit_types[id]

        if ut.level == level and ut.max_moves > 2 then
            table.insert(level_available, id)

            local cfg = unit_cfg_cache[id]
            if cfg == nil then
                cfg = ut.__cfg
                unit_cfg_cache[id] = cfg
            end

            if cfg.alignment == alignment and cfg.role == role then
                table.insert(available, id)
            end
        end
    end

    if #available == 0 then
        -- if the conditions are unsatisfiable, generate at least something
        available = level_available
    end

    return cc.choice(available)
end

function wesnoth.wml_actions.cw_generate_creeps(cfg_raw)
    local cfg = cfg_raw.__parsed

    local score = cfg.score
    local count = cfg.count
    local variable = cfg.variable
    local locations = helper.get_variable_array(cfg.locations)
    local data = {}

    local units = cc.synchronize_choice(function()
        local available_locations = {}
        local units = {}

        for i = 1, #locations do
            available_locations[i] = locations[i]
        end

        for i = 1, count do
            local j = cc.choice_index(available_locations)
        
            table.insert(units, {
                id = generate_one(score, data),
                x = available_locations[j].x,
                y = available_locations[j].y
            })

            table.remove(available_locations, j)
        end

        return units
    end)

    helper.set_variable_array(variable, units)
end

>>
