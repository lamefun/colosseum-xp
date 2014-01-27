<<

-------------------------------------------------------------------------------
-- 
--  Colosseum XP glorious menu engine.
--
--  Documentation is in docs/cc_menu.txt
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

cc.menu = {}
cc.menu_items = {}
cc.menu_sections = {}

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
-- cc_menu tag parsing
-------------------------------------------------------------------------------

local function parse_item(cfg, buyable)
    return {
        name          = cfg.name or wml_error("menu item has to have a name"),
        info          = cfg.info,
        subtitle      = cfg.subtitle,
        image         = cfg.image,

        preshow       = wml_find_cfg(cfg, "preshow"),
        postshow      = wml_find_cfg(cfg, "postshow"),
        preactivate   = wml_find_cfg(cfg, "preactivate"),
        postactivate  = wml_find_cfg(cfg, "postactivate"),
        show_if       = wml_find_cfg(cfg, "show_if"),
        command       = wml_find_cfg(cfg, "command") or wml_error("menu item has to have a command"),

        buyable       = buyable,
        price         = buyable and (cfg.price or wml_error("buyable item has to have a price")) or nil,
        have_all_text = cfg.have_all_text or _('have all'),
        have_all_if   = buyable and wml_find_cfg(cfg, "have_all_if") or nil,
        check_buyable = buyable and wml_find_cfg(cfg, "check_buyable") or nil,
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
        parent      = parent,
        id          = id,

        name        = cfg.name  or wml_error("menu section has to have a name"),
        image       = cfg.image,
        image_attr  = cfg.image_attr,
        speaker     = cfg.speaker,
        header      = cfg.header,

        indicators  = wml_find_many_tags(cfg, "indicator"),

        preshow     = wml_find_cfg(cfg, "preshow"),
        postshow    = wml_find_cfg(cfg, "postshow"),
        show_if     = wml_find_cfg(cfg, "show_if"),
        command     = wml_find_cfg(cfg, "command"),

        items       = items,
        sections    = sections
    }

    -- Parse items
    --------------

    local sub_section_number = 1

    for i,tag in ipairs(cfg) do
        if tag[1] == "item" then
            table.insert(items, parse_item(tag[2], false))
        elseif tag[1] == "buyable" then
            table.insert(items, parse_item(tag[2], true))
        elseif tag[1] == "section" then
            table.insert(sections, parse_section(tag[2], section, sub_section_number))
            sub_section_number = sub_section_number + 1
        elseif cc.menu_items[tag[1]] ~= nil then
            table.insert(items, cc.menu_items[tag[1]](tag[2]))
        end
    end

    return section
end

-------------------------------------------------------------------------------

local function clear_variable(name)
    wesnoth.fire("clear_variable", { name = name })
end

-------------------------------------------------------------------------------

local function maybe_fire_command(command_cfg)
    local cfg_type = type(command_cfg)
    
    if cfg_type == "table" then
        wesnoth.fire("command", command_cfg)
    elseif cfg_type == "function" then
        command_cfg()
    end
end

local function maybe_check_condition(condition_cfg, if_nil)
    local cfg_type = type(condition_cfg)
    if cfg_type == "table" then
        return wesnoth.eval_conditional(condition_cfg)
    elseif cfg_type == "function" then
        return condition_cfg
    else
        return if_nil
    end
end

-------------------------------------------------------------------------------

local function check_buyable_status(item)
    if not maybe_check_condition(item.show_if, true) then
        return 'hidden'
    end

    if item.check_buyable ~= nil then
        wesnoth.set_variable("cc_unbuyable", false)
        wesnoth.set_variable("cc_unbuyable_reason", item.have_all_text or _"have all")

        wesnoth.fire("command", item.check_buyable)

        local unbuyable = wesnoth.get_variable("cc_unbuyable")
        
        if unbuyable == true or unbuyable == "true" or unbuyable == "yes" then
            return 'unbuyable', wesnoth.get_variable("cc_unbuyable_reason")
        end

        clear_variable("cc_unbuyable")
        clear_variable("cc_unbuyable_reason")
    elseif maybe_check_condition(item.have_all_if, false) then
        return 'unbuyable', item.have_all_text or _"have all"
    end

    local too_expensive = wesnoth.eval_conditional {
        { "variable", { 
            name = "cc_menu_gold",
            less_than = item.price 
        }}
    }

    if too_expensive then
        return 'too_expensive'
    end

    return 'buyable'
end

-------------------------------------------------------------------------------
-- Section showing
-------------------------------------------------------------------------------

local function preshow_section(section)
    maybe_fire_command(section.preshow)
    for i,item in ipairs(section.items) do
        maybe_fire_command(item.preshow)
    end
end

local function postshow_section(section)
    for i,item in ipairs(section.items) do
        maybe_fire_command(item.postshow)
    end
    maybe_fire_command(section.postshow)
end

local function show_section(section)
    local start = os.clock()

    -- Set variable that will indicate index of the activated item
    --------------------------------------------------------------

    wesnoth.set_variable("cc_menu_activated_item", 0)

    -- Find out speaker and image_attr
    ----------------------------------

    local function inherited_get(name)
        local value = section[name]

        if value == nil then
            local parent = section.parent
            while parent ~= nil do
                if parent[name] ~= nil then
                    value = parent[name]
                    break
                else
                    parent = parent.parent
                end
            end
        end

        return value
    end

    local image_attr = inherited_get("image_attr")
    local speaker    = inherited_get("speaker") or "narrator"

    -- Generate header
    ------------------

    local header = "<span foreground='gold'>Gold: $cc_menu_gold</span>"

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

    -- Generate message
    -------------------

    local message_cfg = {
        speaker = speaker,
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
                name = "cc_menu_location",
                value = section.parent and section.parent.id or "e"
            }}
        }}
    }})

    -- Generate options for items
    -----------------------------

    for i,item in ipairs(section.items) do
        -- Name text
        ------------

        local name = item.name

        if item.info ~= nil then
            name = name .. string.format(" <span size='small' color='#9999aa'>(%s)</span>", item.info)
        end

        -- Benefit text
        ---------------
    
        local subtitle_text=""

        if item.subtitle ~= nil then
            subtitle_text = string.format(
                "\n<span size='small' foreground='#aaaaaa'>%s</span>", 
                item.subtitle)
        end

        -- Image
        --------

        local image = item.image and item.image .. (image_attr or "") or ""

        -- Option
        ---------

        if item.buyable then
            local status, reason = check_buyable_status(item)
            if status == 'buyable' then
                table.insert(message_cfg, { "option", {
                    message=string.format(
                        "&%s=<span foreground='#88ff22'>%i gold</span>: %s%s",
                        image, item.price, name, subtitle_text),

                    { "command", {
                        { "gold", {
                            side = "$side_number",
                            amount = -item.price
                        }},

                        { "command", {
                            { "set_variable", {
                                name = "cc_menu_activated_item",
                                value = i
                            }}
                        }}
                    }}
                }})
            elseif status == 'too_expensive' then
                table.insert(message_cfg, { "option", {
                    message=string.format(
                        "&%s=<span foreground='#ff4411'>%i gold</span>: %s%s",
                        image, item.price, name, subtitle_text),
                }})
            elseif status == 'unbuyable' then
                table.insert(message_cfg, { "option", {
                    message=string.format(
                        "&%s=<span foreground='#eecc22'>%s</span>: %s%s",
                        image, reason, name, subtitle_text),
                }})
            end
        else
            if maybe_check_condition(item.show_if, true) then
                table.insert(message_cfg, { "option", {
                    message=string.format("&%s=%s%s", image, name, subtitle_text),
                    { "command", {
                        { "set_variable", {
                            name = "cc_menu_activated_item",
                            value = i
                        }}
                    }}
                }})
            end
        end
    end

    -- Generate options for sub-sections
    ------------------------------------

    for i,sub in ipairs(section.sections) do
        local image = sub.image and sub.image .. (image_attr or "") or ""

        local option_cfg = {
            message=string.format("&%s=%s", image, sub.name),

            { "command", {
                { "set_variable", {
                    name = "cc_menu_location",
                    value = sub.id
                }}
            }}
        }

        if sub.show_if ~= nil then
            table.insert(option_cfg, { "show_if", sub.show_if })
        end

        table.insert(message_cfg, { "option", option_cfg })
    end

    section_time = section_time + os.clock() - start
    section_num  = section_num + 1
    item_num     = item_num + #section.items + #section.sections

    -- Show the message
    -------------------

    wesnoth.fire("message", message_cfg)

    -- If an item was activated, do its commands
    --------------------------------------------

    local activated_index = wesnoth.get_variable("cc_menu_activated_item")
    if activated_index ~= 0 then
        local item = section.items[activated_index]
        maybe_fire_command(item.preactivate)
        maybe_fire_command(item.command)
        maybe_fire_command(item.postactivate)
    end
end

-------------------------------------------------------------------------------

local function warn_still_byuable(section)
    local have_buyable = false

    local function with_all(section, fn)
        fn(section)
        for i,sub in ipairs(section.sections) do
            with_all(sub, fn)
        end
    end

    local function check_items(section)
        for i,item in ipairs(section.items) do
            if check_buyable_status(item) == 'buyable' then
                have_buyable = true
            end
        end
    end

    with_all(section, preshow_section)
    with_all(section, check_items)
    with_all(section, postshow_section)

    if have_buyable == true then
        wesnoth.fire("message", {
            speaker = "narrator",
            caption = _"You haven't spent all your gold",
            message = _"There are still things you can buy in this shop. Are you sure you want to exit?",

            { "option", {
                message = _"&items/ball-green.png~SCALE(24,24)=Yes",
            }},

            { "option", {
                message = _"&items/ball-magenta.png~SCALE(24,24)=No",
                { "command", {
                    { "set_variable", {
                        name = "cc_menu_location",
                        value = "r"
                    }}
                }}
            }}
        })
    end
    
    return true
end

-------------------------------------------------------------------------------

function wesnoth.wml_actions.cc_menu(cfg_raw)

    parse_time = 0
    section_time = 0
    section_num = 0
    item_num = 0
    local start = os.clock()

    -- get __literal from cfg_raw and delocalize it
    -----------------------------------------------

    local cfg = delocalize_tag_cfg(cfg_raw.__literal)

    -- Parse the cc_menu tag
    ------------------------

    cc.transform(cfg)

    local root_section = parse_section(cfg, nil)

    -- Make section-by-id table 
    ---------------------------
    
    local section_by_id = {}

    local function populate_section_by_id(section)
        section_by_id[section.id] = section
        for i,sub in ipairs(section.sections) do
            populate_section_by_id(sub)
        end
    end

    populate_section_by_id(root_section)

    local parse_time = os.clock() - start

    -- Location in the currently open shop
    --
    --  e     - exit the shop
    --  r     - root section
    --  r.1   - section 1
    --- r.N   - section N
    --  r.N.M - sub-section M in section N
    wesnoth.set_variable("cc_menu_location", "r")

    while true do
        wesnoth.fire("store_gold", {
            side = "$side_number",
            variable = "cc_menu_gold"
        })

        local location = wesnoth.get_variable("cc_menu_location")

        if location == "e" then
            warn_still_byuable(root_section)

            location = wesnoth.get_variable("cc_menu_location")
            if location == "e" then
                break
            end
        end

        local section = section_by_id[location]
        preshow_section(section)
        show_section(section)
        postshow_section(section)
    end

    clear_variable("cc_menu_location")
    clear_variable("cc_menu_gold")

    -- wesnoth.message(string.format("shop performance: %.2f sec parser, %.2f sec generator (avg %.2f per section (%i total), %.2f per item (%i total))", 
    --     parse_time, section_time, section_time / section_num, section_num, section_time / item_num, item_num))
end

>>
