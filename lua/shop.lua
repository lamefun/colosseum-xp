<<

-------------------------------------------------------------------------------
-- 
-- This is shop engine of Colosseum XP. If this is insane / stupid / could be
-- done easier, please tell me.
--
-- Usage:
--
--  [cs_shop]
--      # Caption of the shop
--      caption=_"Upgrade"
--
--      # Attributes for menu item images.
--      image_attr="~SCALE(32,32)"
--
--      [section]
--          name=_"Name"
--          image=attacks/blank.png
--          header=_"Here you can buy some items"
--
--          [prepare]
--              # Actions executed before the rest of the tag is processed.
--              # For example, you can set a variable here and use it in an
--              # indicator.
--          [/prepare]
--
--          # Indicator, shown along with gold, eg. this one will be shown as:
--          # Gold: XX | Training left: XX
--          [indicator]
--              name=_"Training left"
--              value=$training_left
--          [/indicator]
--
--          [command]
--              # If present, this will be executed instead of showing items.
--          [/command]
--
--          # Entirely custom item
--          [custom]
--              price=35
--              name=_"name"
--              benefits=_"subtitle (eg. benefits of the item)"
--              image=attacks/blank.png
--              have_all_text=_"already have all"
--
--              [prepare]
--                  # Actions executed before the rest of the tag is processed.
--                  # For example, you can set a variable here and use it in
--                  # item's name.
--              [/prepare]
--
--              [show_if]
--                  # If present and not empty, item will only be shown when
--                  # all condition in this tag are met.
--              [/show_if]
--
--              [buyable_if]
--                  # If present and not empty, item can only be shown when
--                  # all condition in this tag are met, even if there's enough
--                  # gold to buy it.
--              [/buyable_if]
--
--              [have_all_if]
--                  # If present, means that you can only buy one of this item.
--                  # 
--              [/have_all_if]
--
--              [store_count]
--                  # If present, means that you can buy more than one of this
--                  # item. You MUST set the cs_shop_count variable to the
--                  # current number of the items of this type the buyer has,
--                  # and, optionally, set the cs_shop_max_count variable to
--                  # the maximum number of the items the buyer can buy.
--              [/store_count]
--
--              [command]
--                  # Required. Command executed when the player buys the item.
--              [/command]
--          [/custom]
--
--          # A weapon (TODO: document)
--          [weapon]
--          [/weapon]
--      [/section]
--  [/cs_shop]
--
-------------------------------------------------------------------------------

local helper    = wesnoth.require("lua/helper.lua")
local wml_error = helper.wml_error
local textdomain = wesnoth.textdomain("wesnoth-colosseum-xp")

local function _(s)
    return tostring(textdomain(s))
end

-------------------------------------------------------------------------------
-- Delocalizer, because string.format doesn't understand userdata
-------------------------------------------------------------------------------

function delocalize_tag_content(content)
    local delocalized = {}

    for k,v in pairs(content) do
        if type(k) == "string" then
            local t = type(v)
            
            if t == "nil" then
                delocalized[k] = v
            elseif t == "boolean" then
                delocalized[k] = v
            elseif t == "number" then
                delocalized[k] = v
            elseif t == "string" then
                delocalized[k] = v
            else
                delocalized[k] = tostring(v)
            end
        elseif type(k) == "number" then
            delocalized[k] = delocalize_tag(v)
        end
    end
    
    return delocalized
end

function delocalize_tag(tag)
    return { tostring(tag[1]), delocalize_tag_content(tag[2]) }
end

-------------------------------------------------------------------------------
-- Helpers
-------------------------------------------------------------------------------

local function wml_subtag(tag, name)
    for i,subtag in ipairs(tag[2]) do
        if subtag[1] == name then
            return subtag
        end
    end
    return nil
end

local function wml_many_subtags(tag, name)
    local subtags = {}
    for i,subtag in ipairs(tag[2]) do
        if subtag[1] == name then
            table.insert(subtags, subtag)
        end
    end
    return subtags
end

-------------------------------------------------------------------------------
-- cs_shop tag parsing
-------------------------------------------------------------------------------

local function parse_custom_item(item_tag)
    return {
        price         = item_tag[2].price or wml_error("shop item has to have a price"),
        name          = item_tag[2].name or wml_error("shop item has to have a name"),
        benefits      = item_tag[2].benefits,
        image         = item_tag[2].image,
        have_all_text = item_tag[2].have_all_text or _('have all'),
        prepare       = wml_subtag(item_tag, "prepare"),
        show_if       = wml_subtag(item_tag, "show_if"),
        have_all_if   = wml_subtag(item_tag, "have_all_if"),
        store_count   = wml_subtag(item_tag, "store_count"),
        command       = wml_subtag(item_tag, "command") or wml_error("shop item has to have a command")
    }
end

local function parse_weapon_item(item_tag)
    local function parse_weapon(tag)
        return {
            name      = tag[2].name      or wml_error("weapon must have name"),
            user_name = tag[2].user_name or wml_error("weapon must have user name"),
            image     = tag[2].image     or wml_error("weapon must have image"),
            range     = tag[2].range     or wml_error("weapon must have range"),
            type      = tag[2].type      or wml_error("weapon must have type"),
            damage    = tag[2].damage    or wml_error("weapon must have damage"),
            strikes   = tag[2].strikes   or wml_error("weapon must have strikes"),
            specials  = wml_subtag(tag, "specials"),
            effects   = wml_many_subtags(tag, "effect")
        }
    end

    local function benefits_of(weapon)
        local benefits = tostring(weapon.damage) .. 
                         "-" .. tostring(weapon.strikes) .. 
                         " " .. weapon.range ..
                         ", " .. weapon.type

        if weapon.specials ~= nil then
            for i,special_tag in ipairs(weapon.specials[2]) do
                benefits = benefits .. ", " .. special_tag[2].name
            end
        end

        return benefits
    end

    local function add_effects(weapon, t)
        local main_effect = { "effect", {
            apply_to = "new_attack",
            name = weapon.name,
            description = weapon.user_name,
            icon = weapon.image,
            range = weapon.range,
            type = weapon.type,
            damage = weapon.damage,
            number = weapon.strikes
        }}

        if weapon.specials ~= nil then
            table.insert(main_effect[2], { "specials", weapon.specials[2] })
        end

        table.insert(t, main_effect)

        if weapon.effects ~= nil then
            for i,effect in ipairs(weapon.effects) do
                table.insert(t, effect)
            end
        end
    end

    local price     = item_tag[2].price or wml_error("shop item has to have a price")
    local primary   = parse_weapon(item_tag)
    local secondary = nil

    if wml_subtag(item_tag, "secondary") then
       secondary = parse_weapon(wml_subtag(item_tag, "secondary"))
    end

    local benefits = benefits_of(primary)

    local object_content = {
        silent = true
    }

    add_effects(primary, object_content)
    
    if secondary ~= nil then
        benefits = benefits .. " &amp; " .. benefits_of(secondary)
        add_effects(secondary, object_content)
    end

    local command_content = {
        { "object", object_content }
    }

    local prebuy = wml_subtag(item_tag, "prebuy")

    if prebuy ~= nil then
        table.insert(command_content, 1, { "command", prebuy[2] })
    end

    return {
        price = price,
        name = primary.user_name,
        image = primary.image,
        benefits = benefits,
        prepare  = wml_subtag(item_tag, "prepare"),
        have_all_text = _("already have"),
        have_all_if = { "have_all_if", {
            { "have_unit", {
                x = "$x1",
                y = "$y1",

                has_weapon = primary.name
            }}
        }},
        command = { "command", command_content }
    }
end

local function parse_section(section_tag)
    local items = {}

    for i,tag in ipairs(section_tag[2]) do
        if tag[1] == "custom" then
            table.insert(items, parse_custom_item(tag))
        elseif tag[1] == "weapon" then
            table.insert(items, parse_weapon_item(tag))
        end
    end

    return {
        name       = section_tag[2].name or wml_error("shop section has to have a name"),
        image      = section_tag[2].image or "",
        header     = section_tag[2].header,
        indicators = wml_many_subtags(section_tag, "indicator"),
        prepare    = wml_subtag(section_tag, "prepare"),
        show_if    = wml_subtag(section_tag, "show_if"),
        command    = wml_subtag(section_tag, "command"),
        items      = items
    }
end

-------------------------------------------------------------------------------
-- Message code generation
-------------------------------------------------------------------------------

local function make_section_message(section, image_attr)
    local header = "<span foreground='gold'>Gold: $cs_shop_gold</span>"

    for i,indicator in ipairs(section.indicators) do
        local color = indicator[2].color or '#cccccc'
        header = string.format("%s | <span foreground='%s'>%s</span>: %s",
            header, color, tostring(indicator[2].name), 
            tostring(indicator[2].value))
    end

    header = header .. "\n"
    
    if section.header ~= nil then
        header = header .. section.header
    end
    
    header = header .. "\n"

    local message = {
        speaker = "narrator",
        caption = section.name, 
        message = header
    }

    -- Back button
    table.insert(message, { "option", {
        message="&items/ball-green.png"  .. image_attr .. "=" .. _("Back"),

        { "command", {
            { "set_variable", {
                name = "cs_shop_location",
                value = 0
            }}
        }}
    }})

    -- Item list
    for i,item in ipairs(section.items) do
        local benefit_text=""

        if item.benefits ~= nil then
            benefit_text = string.format(
                "\n<span size='small' foreground='#aaaaaa'>%s</span>", 
                item.benefits)
        end

        local image = item.image
        
        if image ~= nil then
            image = image .. image_attr
        else
            image = ''
        end

        -- When the item is buyable
        table.insert(message, { "option", {
            message=string.format(
                "&%s=<span foreground='#88ff22'>%i gold</span>: %s%s",
                image, item.price, item.name, benefit_text),

            { "show_if", {
                { "variable", {
                    name = item.status_variable,
                    equals = "buyable"
                }}
            }},

            { "command", {
                { "gold", {
                    side = "$side_number",
                    amount = -item.price
                }},

                item.command
            }}
        }})

        -- When the item is not affordable
        table.insert(message, { "option", {
            message=string.format(
                "&%s=<span foreground='#ff4411'>%i gold</span>: %s%s",
                image, item.price, item.name, benefit_text),

            { "show_if", {
                { "variable", {
                    name = item.status_variable,
                    equals = "too_expensive"
                }}
            }}
        }})

        -- When the item has already been bought
        table.insert(message, { "option", {
            message=string.format(
                "&%s=<span foreground='#eecc22'>%s</span>: %s%s",
                image, item.have_all_text, item.name, benefit_text),

            { "show_if", {
                { "variable", {
                    name = item.status_variable,
                    equals = "have_all"
                }}
            }}
        }})
    end

    return message
end

local function make_section_list_message(sections, caption, image_attr)
    local message = {
        speaker = "narrator", 
        caption = caption,
        message = "<span foreground='gold'>Gold: $cs_shop_gold</span>\n$cs_shop_header\n"
    }

    -- Done button
    table.insert(message, { "option", {
        message="&items/ball-green.png" .. image_attr .. "=" .. _("Done"),

        { "command", {
            { "if", {
                { "variable", {
                    name = "cs_shop_have_buyable_items",
                    equals = "no"
                }},
                
                { "then", {
                    { "set_variable", {
                        name = "cs_shop_location",
                        value = -1
                    }}
                }},
                
                { "else", {
                    { "message", {
                        speaker = "narrator",
                        message = _("You haven't spent all your gold. Are you sure you want to exit the shop?"),

                        { "option", {
                            message=_("&=Yes"),
                            { "command", {
                                { "set_variable", {
                                    name = "cs_shop_location",
                                    value = -1
                                }}
                            }}
                        }},
    
                        { "option", {
                            message=_("&=No"),
                        }}
                    }}
                }}
            }}
        }}
    }})

    -- Section list
    for i,section in ipairs(sections) do
        local option_content = {
            message="&" .. section.image .. image_attr .. "=" .. section.name,

            { "command", {
                { "set_variable", {
                    name = "cs_shop_location",
                    value = i
                }},
            }}
        }
    
        if section.show_if ~= nil then
            table.insert(option_content, { "show_if", section.show_if[2] })
        end
    
        table.insert(message, { "option", option_content })
    end

    return message
end

function wesnoth.wml_actions.cs_shop(cfg_raw)

    -- get __literal from cfg_raw and delocalize it
    -----------------------------------------------

    local cfg = delocalize_tag_content(cfg_raw.__literal)

    -- Parse the cs_shop tag
    ------------------------

    local caption = cfg.caption or _("Shop")
    local image_attr = cfg.image_attr or ""
    local sections = {}

    for i,tag in ipairs(cfg) do
        if tag[1] == "section" then
            table.insert(sections, parse_section(tag))
        else
            wml_error("unknown [cs_shop] subtag [" .. tag.name .. "]")
        end
    end

    -- Generate preparation code
    ----------------------------

    local prepare_actions = {}

    for i,section in ipairs(sections) do
        if section.prepare ~= nil then
            table.insert(prepare_actions, { "command", section.prepare[2] })
        end
    end

    for i,section in ipairs(sections) do
        for j,item in ipairs(section.items) do
            if item.prepare ~= nil then
                table.insert(prepare_actions, { "command", item.prepare[2] })
            end
        end
    end

    -- Generate code that checks statuses of items
    ----------------------------------------------
    
    local status_check_actions = {}
    
    for i,section in ipairs(sections) do
        for j,item in ipairs(section.items) do
            local status_variable    = "tmp_shop_item_status_" .. 
                                       tostring(i) .. "_" .. tostring(j)
            local count_variable     = status_variable .. "_count"
            local max_count_variable = status_variable .. "_max_count"

            item.status_variable    = status_variable
            item.count_variable     = count_variable
            item.max_count_variable = max_count_variable

            -- Create / reset the variables that store the status
            -----------------------------------------------------

            -- Possible statuses:
            --
            -- buyable       - can buy
            -- hidden        - hidden from view entirely 
            -- have_all      - already have maximum amount
            -- too_expensive - can't afford
            
            table.insert(status_check_actions, { "set_variable", {
                name=status_variable,
                value="unknown"    
            }})

            -- hidden check
            ----------------- 

            if item.show_if ~= nil then
                table.insert(status_check_actions, { "if", {
                    { "not", {
                        { "and", item.show_if[2] }
                    }},

                    { "then", {
                        { "set_variable", {
                            name = status_variable,
                            value = "hidden"
                        }}
                    }}
                }})
            end

            -- have_all check
            -----------------        

            if item.have_all_if ~= nil then
                table.insert(status_check_actions, { "if", {
                    { "variable", {
                        name = status_variable,
                        equals = "unknown",
                    }},

                    { "and", item.have_all_if[2] },

                    { "then", {
                        { "set_variable", {
                            name = status_variable,
                            value = "have_all"
                        }}
                    }}
                }})
            elseif item.store_count ~= nil then
                wesnoth.set_variable(count_variable, -1)
                wesnoth.set_variable(max_count_variable, -1)

                table.insert(status_check_actions, { "if", {
                    { "variable", {
                        name = status_variable,
                        equals = "unknown",
                    }},
                    
                    { "then", {
                        -- Clear
                    
                        { "set_variable", {
                            name = "cs_shop_count",
                            value = -1
                        }},

                        { "set_variable", {
                            name = "cs_shop_max_count",
                            value = -1
                        }},

                        -- Retrieve

                        { "command", item.store_count[2] },

                        -- Copy to item-specific variables

                        { "set_variable", {
                            name = count_variable,
                            value = "$cs_shop_count"
                        }},

                        { "set_variable", {
                            name = max_count_variable,
                            value = "$cs_shop_max_count"
                        }},

                        -- Check

                        { "if", {
                            { "variable", {
                                name = "cs_shop_count",
                                greater_than_equal_to = "$cs_shop_max_count"
                            }},

                            { "then", {
                                { "set_variable", {
                                    name = status_variable,
                                    value = "have_all"
                                }}
                            }}
                        }},

                        -- Clear

                        { "set_variable", {
                            name = "cs_shop_count",
                            value = -1
                        }},

                        { "set_variable", {
                            name = "cs_shop_max_count",
                            value = -1
                        }}
                    }}
                }})
            end

            -- too_expensive check
            ----------------------

            table.insert(status_check_actions, { "if", {
                { "variable", {
                    name = status_variable,
                    equals = "unknown",
                }},

                { "variable", {
                    name = "cs_shop_gold",
                    less_than = item.price
                }},

                { "then", {
                    { "set_variable", {
                        name = status_variable,
                        value = "too_expensive"
                    }}
                }}
            }})

            -- it's buyable then
            --------------------

            table.insert(status_check_actions, { "if", {
                { "variable", {
                    name = status_variable,
                    equals = "unknown",
                }},

                { "then", {
                    { "set_variable", {
                        name = status_variable,
                        value = "buyable"
                    }},

                    { "set_variable", {
                        name = "cs_shop_have_buyable_items",
                        value = "yes"
                    }}
                }}
            }})
        end
    end

    -- Location switcher
    --------------------

    local location_switch_cases = {
        variable="cs_shop_location"
    }

    -- Location in the shop
    --
    -- -1  - exit shop
    --  0  - shop section list
    --  x  - section number x
    wesnoth.set_variable("cs_shop_location", 0)

    table.insert(location_switch_cases, { "case", {
        value = -1
    }})

    table.insert(location_switch_cases, { "case", {
        value = 0,
        { "message", make_section_list_message(sections, caption, image_attr) }
    }})

    for i,section in ipairs(sections) do
        if section.command == nil then
            table.insert(location_switch_cases, { "case", {
                value = i,
                { "message", make_section_message(section, image_attr) }
            }})
        else
            table.insert(location_switch_cases, { "case", {
                value = i,
                { "command", section.command[2] },
                { "set_variable", {
                    name = "cs_shop_location",
                    value = 0
                }}
            }})
        end
    end

    -- Show the shop message
    ------------------------

    wesnoth.fire("while", {
        { "variable", {
            name = "cs_shop_location",
            not_equals = -1
        }},

        { "do", {
            { "store_gold", {
                side = "$side_number",
                variable = "cs_shop_gold"
            }},

            { "set_variable", {
                name = "cs_shop_have_buyable_items",
                value = "no"
            }},

            { "command", prepare_actions },
            { "command", status_check_actions },

            { "if", {
                { "variable", {
                    name = "cs_shop_have_buyable_items",
                    equals = "no"
                }},

                { "then", {
                    { "set_variable", {
                        name = "cs_shop_header",
                        value = _("There's nothing in the shop you can afford anymore. Select the \"Done\" option to exit the shop.")
                    }},
                }},

                { "else", {
                    { "set_variable", {
                        name = "cs_shop_header",
                        value = ""
                    }},
                }}
            }},

            { "switch", location_switch_cases }
        }}
    })
end

>>
