<<

-------------------------------------------------------------------------------
-- 
--  This is shop engine of Colosseum XP. If this is insane / stupid / could be
--  done easier, please tell me.
--
--  Usage:
--
--  [cs_shop]
--      # The shop root is itself a section, so all attributes from the
--      # [section] subtag can be used here.
--
--      id=upgrade
--
--      [section]
--          name=_"Name"
--          image=attacks/blank.png
--          header=_"Here you can buy some items"
--
--          # Attributes for all images in this section. Also, applies to
--          # sub-sections, unless re-defined in the sub-sections themselves.
--          image_attr="~SCALE(32,32)"
--
--          [prepare]
--              # Actions executed before the section is shown.
--              # See item's prepare.
--          [/prepare]
--
--          [cleanup]
--              # Actions executed before the section is shown.
--              # See item's cleanup.
--          [/cleanup]
--
--          # Indicator, shown along with gold, eg. this one will be shown as:
--          # Gold: XX | Training left: XX
--          [indicator]
--              name=_"Training left"
--              value=$training_left
--          [/indicator]
--
--          [command]
--              # If present, this command will be executed instead of showing
--              # items.
--          [/command]
--
--          # A shop item
--          [item]
--              price=35
--              name=_"name"
--              benefits=_"subtitle (eg. benefits of the item)"
--              image=attacks/blank.png
--              have_all_text=_"already have all"
--
--              [prepare]
--                  # Actions executed each time the section containing the
--                  # item is shown, before the item itself is processed.
--
--                  # The variables set here can be used in other parts of the
--                  # items, eg.
--
--                  # [item]
--                  #     name=$hello
--                  #     [prepare]
--                  #         {VARIABLE hello "Hello $side_number"}
--                  #     [/prepare]
--                  # [/item] 
--              [/prepare]
--
--              [cleanup]
--                  # Actions executed each time the section containing the
--                  # item is shown.
--
--                  # This is where you clean up variables set in [prepare].
--              [/cleanup]
--
--              [show_if]
--                  # If present and not empty, item will only be shown when
--                  # all condition in this tag are met.
--
--                  # Sub-tags [and], [or], [not] can be used.
--              [/show_if]
--
--              [have_all_if]
--                  # If present and not empty, item will only be buyable if
--                  # all conditions in this tag are not met. Otherwise,
--                  # have_all_text will be shown instead of price.
--
--                  # Sub-tags [and], [or], [not] can be used.
--              [/have_all_if]
--
--              [command]
--                  # Required. Command executed when the player buys the item.
--              [/command]
--          [/item]
--
--          # Sub-section
--          [section]
--              # ...
--          [/section]
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
-- Put funtions in this table to register section and item types
-------------------------------------------------------------------------------

cs_shop = {}
cs_shop.item = {}
cs_shop.section = {}

-------------------------------------------------------------------------------
-- Delocalizer, because string.format doesn't understand userdata
-------------------------------------------------------------------------------

function delocalize_tag_cfg(content)
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
    return { tostring(tag[1]), delocalize_tag_cfg(tag[2]) }
end

-------------------------------------------------------------------------------
-- Helpers
-------------------------------------------------------------------------------

-- Finds the first sub-tag with the given name in tag's content (tag[2]).
function wml_find_tag(cfg, name)
    for i,tag in ipairs(cfg) do
        if tag[1] == name then
            return tag
        end
    end

    return nil
end

-- Finds the first sub-tag with the given name in the given tag content
-- (tag[2]), and returns its content (subtag[2]).
function wml_find_cfg(cfg, name)
    local tag = wml_find_tag(cfg, name)

    if tag ~= nil then
        return tag[2]
    end

    return nil
end

-- Finds all sub-tags with the given name in tag's content (tag[2]).
function wml_find_many_tags(cfg, name)
    local tags = {}

    for i,tag in ipairs(cfg) do
        if tag[1] == name then
            table.insert(tags, tag)
        end
    end

    return tags
end

-------------------------------------------------------------------------------
-- cs_shop tag parsing
-------------------------------------------------------------------------------

local function parse_item(cfg)
    return {
        price         = cfg.price         or wml_error("shop item has to have a price"),
        name          = cfg.name          or wml_error("shop item has to have a name"),
        benefits      = cfg.benefits,
        image         = cfg.image,
        have_all_text = cfg.have_all_text or _('have all'),

        prepare       = wml_find_cfg(cfg, "prepare"),
        cleanup       = wml_find_cfg(cfg, "cleanup"),
        show_if       = wml_find_cfg(cfg, "show_if"),
        have_all_if   = wml_find_cfg(cfg, "have_all_if"),
        command       = wml_find_cfg(cfg, "command") or wml_error("shop item has to have a command")
    }
end

local function parse_section(cfg, parent, number)
    -- Tables for items and section
    -------------------------------

    local items = {}
    local sections = {}

    -- Calculate ID
    ---------------

    local id = parent and parent.id .. "." .. tostring(number) or "r"

    -- Table for section, need to declare now, sub-sections need it as parent
    -------------------------------------------------------------------------

    local section = {
        parent     = parent,
        id         = id,

        name       = cfg.name  or wml_error("shop section has to have a name"),
        image      = cfg.image,
        image_attr = cfg.image_attr,
        header     = cfg.header,

        indicators = wml_find_many_tags(cfg, "indicator"),

        prepare    = wml_find_cfg(cfg, "prepare"),
        show_if    = wml_find_cfg(cfg, "show_if"),
        command    = wml_find_cfg(cfg, "command"),

        items      = items,
        sections   = sections
    }

    -- Parse items
    --------------

    local sub_section_number = 1

    for i,tag in ipairs(cfg) do
        if tag[1] == "item" then
            table.insert(items, parse_item(tag[2]))
        elseif tag[1] == "section" then
            table.insert(sections, parse_section(tag[2], section, sub_section_number))
            sub_section_number = sub_section_number + 1
        elseif cs_shop.item[tag[1]] ~= nil then
            table.insert(items, cs_shop.item[tag[1]](tag[2]))
        end
    end

    return section
end

-------------------------------------------------------------------------------
-- Section command generation
-------------------------------------------------------------------------------

local function generate_section_command(section)
    -- Handle sections with [command]
    ---------------------------------

    if section.command ~= nil then
        return { "command", {
            { "command", section.command },
            { "set_variable", {
                name = "cs_shop_location",
                value = section.parent and section.parent.id or "e"
            }}
        }}
    end

    -- Find image_attr
    ------------------

    local image_attr = section.image_attr

    if image_attr == nil then
        local parent = section.parent
        while parent ~= nil do
            if parent.image_attr ~= nil then
                image_attr = parent.image_attr
                break
            else
                parent = parent.parent
            end
        end
    end

    -- Generate header
    ------------------

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

    -- Generate preparation and cleanup commands for items
    ------------------------------------------------------

    local items_prepare_cfg = {}
    local items_cleanup_cfg = {}

    for i,item in ipairs(section.items) do
        if item.prepare ~= nil then
            table.insert(items_prepare_cfg, { "command", item.prepare })
        end

        if item.cleanup ~= nil then
            table.insert(items_cleanup_cfg, { "command", item.cleanup })
        end
    end

    -- Generate code that checks statuses of items
    ----------------------------------------------
    
    local items_check_cfg = {}

    for i,item in ipairs(section.items) do
        local status_prefix      = "tmp.cs_shop_item_" .. tostring(i)
        local status_variable    = status_prefix .. "_status"
        local count_variable     = status_prefix .. "_count"
        local max_count_variable = status_prefix .. "_max_count"

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
        
        table.insert(items_check_cfg, { "set_variable", {
            name=status_variable,
            value="unknown"    
        }})

        -- hidden check
        ---------------

        if item.show_if ~= nil then
            table.insert(items_check_cfg, { "if", {
                { "not", {
                    { "and", item.show_if }
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
            table.insert(items_check_cfg, { "if", {
                { "variable", {
                    name = status_variable,
                    equals = "unknown",
                }},

                { "and", item.have_all_if },

                { "then", {
                    { "set_variable", {
                        name = status_variable,
                        value = "have_all"
                    }}
                }}
            }})
        end

        -- too_expensive check
        ----------------------

        table.insert(items_check_cfg, { "if", {
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

        table.insert(items_check_cfg, { "if", {
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


    -- Generate message
    -------------------

    local message_cfg = {
        speaker = "narrator",
        caption = section.name, 
        message = header
    }

    -- Back or done button
    ----------------------

    table.insert(message_cfg, { "option", {
        message=string.format("&items/ball-green.png%s=%s",
          image_attr or "", 
          section.parent and _("Back") or _("Done")
        ),

        { "command", {
            { "set_variable", {
                name = "cs_shop_location",
                value = section.parent and section.parent.id or "e"
            }}
        }}
    }})

    -- Generate options for items
    -----------------------------

    for i,item in ipairs(section.items) do
        -- Benefit text
        ---------------
    
        local benefit_text=""

        if item.benefits ~= nil then
            benefit_text = string.format(
                "\n<span size='small' foreground='#aaaaaa'>%s</span>", 
                item.benefits)
        end

        -- Image
        --------

        local image = item.image

        if image ~= nil then
            image = image .. (image_attr or "")
        else
            image = ''
        end

        -- When the item is buyable
        ---------------------------

        table.insert(message_cfg, { "option", {
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

                { "command", item.command }
            }}
        }})

        -- When the item is not affordable
        -----------------------------------

        table.insert(message_cfg, { "option", {
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
        ----------------------------------------

        table.insert(message_cfg, { "option", {
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

    -- Generate options for sub-sections
    ------------------------------------

    for i,sub_section in ipairs(section.sections) do
        local image = sub_section.image

        if image ~= nil then
            image = image .. (image_attr or "")
        else
            image = ''
        end

        local option_cfg = {
            message=string.format("&%s=%s", image, sub_section.name),

            { "command", {
                { "set_variable", {
                    name = "cs_shop_location",
                    value = sub_section.id
                }}
            }}
        }

        if sub_section.show_if ~= nil then
            table.insert(option_cfg, { "show_if", sub_section.show_if })
        end

        table.insert(message_cfg, { "option", option_cfg })
    end


    -- Generate command
    -------------------

    local command_cfg = {
        { "store_gold", {
            side = "$side_number",
            variable = "cs_shop_gold"
        }}
    }

    if section.prepare ~= nil then
        table.insert(command_cfg, { "command", section.prepare })
    end

    table.insert(command_cfg, { "command", items_check_cfg })
    table.insert(command_cfg, { "command", items_prepare_cfg })
    table.insert(command_cfg, { "message", message_cfg })
    table.insert(command_cfg, { "command", items_cleanup_cfg })

    if section.cleanup ~= nil then
        table.insert(command_cfg, { "command", section.cleanup })
    end

    return { "command", command_cfg }
end

-------------------------------------------------------------------------------
-- WML action for shop
-------------------------------------------------------------------------------

function wesnoth.wml_actions.cs_shop(cfg_raw)

    -- get __literal from cfg_raw and delocalize it
    -----------------------------------------------

    local cfg = delocalize_tag_cfg(cfg_raw.__literal)

    -- Parse the cs_shop tag
    ------------------------

    local root_section = parse_section(cfg, nil)

    -- Location switcher
    --------------------

    local location_switch_cases = {
        variable="cs_shop_location"
    }

    -- Location in the currently open shop
    --
    --  e     - exit the shop
    --  r     - root section
    --  r.1   - section 1
    --- r.N   - section N
    --  r.N.M - sub-section M in section N

    wesnoth.set_variable("cs_shop_location", "r")

    table.insert(location_switch_cases, { "case", {
        value = "e"
    }})

    local function generate_section_cases(section)
        table.insert(location_switch_cases, { "case", {
            value = section.id, 
            generate_section_command(section)
        }})

        for i,section in ipairs(section.sections) do
            generate_section_cases(section)
        end
    end

    generate_section_cases(root_section)

    -- Show the shop message
    ------------------------

    wesnoth.fire("while", {
        { "variable", {
            name = "cs_shop_location",
            not_equals = "e"
        }},

        { "do", {
            { "switch", location_switch_cases }
        }}
    })
end

>>
