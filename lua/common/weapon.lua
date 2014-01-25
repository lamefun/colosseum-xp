<<

local textdomain = wesnoth.textdomain("wesnoth-colosseum-xp")
local function _(s)
    return tostring(textdomain(s))
end

function cc_shop.item.weapon(cfg)
    -- Parse
    --------

    local function parse_weapon(cfg)
        return {
            name      = cfg.name      or wml_error("weapon must have name"),
            user_name = cfg.user_name or wml_error("weapon must have user name"),
            image     = cfg.image     or wml_error("weapon must have image"),
            range     = cfg.range     or wml_error("weapon must have range"),
            type      = cfg.type      or wml_error("weapon must have type"),
            damage    = cfg.damage    or wml_error("weapon must have damage"),
            strikes   = cfg.strikes   or wml_error("weapon must have strikes"),

            specials  = wml_find_cfg(cfg, "specials"),
            effects   = wml_find_many_tags(cfg, "effect")
        }
    end

    local price     = cfg.price or wml_error("weapon has to have a price")
    local info      = cfg.info
    local primary   = parse_weapon(cfg)
    local secondary = nil

    local secondary_cfg = wml_find_cfg(cfg, "secondary")
    if secondary_cfg ~= nil then
       secondary = parse_weapon(secondary_cfg)
    end

    -- Generate name text
    ---------------------

    local name = primary.user_name

    if info ~= nil then
        name = name .. string.format(" <span size='small' color='#9999aa'>(%s)</span>", info)
    end

    -- Generate benefits text
    -------------------------

    local function benefits_of(weapon)
        local benefits = string.format("%i-%i %s-%s",
            weapon.damage, weapon.strikes, weapon.range, weapon.type)

        if weapon.specials ~= nil then
            for i,special_tag in ipairs(weapon.specials) do
                benefits = benefits .. ", " .. special_tag[2].name
            end
        end

        return benefits
    end

    local benefits = benefits_of(primary)

    if secondary ~= nil then
        benefits = benefits .. " &amp; " .. benefits_of(secondary)
    end

    -- Generate object to give to the unit
    --------------------------------------

    local function add_effects(weapon, t)
        local main_effect_cfg = {
            apply_to = "new_attack",
            name = weapon.name,
            description = weapon.user_name,
            icon = weapon.image,
            range = weapon.range,
            type = weapon.type,
            damage = weapon.damage,
            number = weapon.strikes
        }

        if weapon.specials ~= nil then
            table.insert(main_effect_cfg, { "specials", weapon.specials })
        end

        table.insert(t, { "effect", main_effect_cfg })

        if weapon.effects ~= nil then
            for i,effect in ipairs(weapon.effects) do
                table.insert(t, effect)
            end
        end
    end

    local object_cfg = {
        silent = true
    }

    add_effects(primary, object_cfg)

    if secondary ~= nil then
        add_effects(secondary, object_cfg)
    end

    -- Return
    ---------

    return {
        price    = price,
        name     = primary.user_name,
        info     = cfg.info,
        image    = primary.image,
        benefits = benefits,

        prepare = wml_find_cfg(cfg, "prepare"),
        cleanup = wml_find_cfg(cfg, "cleanup"),
        prebuy  = wml_find_cfg(cfg, "prebuy"),
        postbuy = wml_find_cfg(cfg, "postbuy"),

        have_all_text = _("already have"),
        have_all_if = {
            { "have_unit", {
                x = "$x1",
                y = "$y1",

                has_weapon = primary.name
            }}
        },

        command = { "object", object_cfg }
    }
end

>>
