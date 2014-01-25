<<

-------------------------------------------------------------------------------
-- 
--  This is shop engine of Colosseum XP. If this is insane / stupid / could be
--  done easier, please tell me.
--
--  Usage:
--
--  [cc_shop]
--      # The shop root is itself a section, so all attributes from the
--      # [section] subtag can be used here.
--
--      id=upgrade
--
--      [section]
--          name=_"Name"
--          image=attacks/blank.png
--          header=_"Here you can buy some items"
--          speaker=$unit.id
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
--              info=_"subtitle shown inside parentheses after the name"
--              benefits=_"subtitle shown below the name"
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
--              [prebuy]
--                  # Actions executed before the item is bought.
--              [/prebuy]
--
--              [postbuy]
--                  # Actions executed after the item is bought.
--              [/postbuy]
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
--              [check_buyable]
--                  # Extended [have_all_if] and have_all_text. Use if the
--                  # item has complex buyability conditions or multiple
--                  # possible reasons to be unbuyable.
--
--                  # You can run arbitrary commands here to check if the
--                  # item is buyable. If it isn't, set cc_unbuyable to yes
--                  # and cc_unbuyable_reason to reason why it is unbuyable.
--                  # If cc_unbuyable is set, but cc_unbuyable_reason isn't,
--                  # have_all_text is used.
--              [/check_buyable]
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
--  [/cc_shop]
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

cc_shop = {}
cc_shop.item = {}
cc_shop.section = {}

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
-- cc_shop tag parsing
-------------------------------------------------------------------------------

local function parse_item(cfg)
    return {
        price         = cfg.price         or wml_error("shop item has to have a price"),
        name          = cfg.name          or wml_error("shop item has to have a name"),
        info          = cfg.info,
        benefits      = cfg.benefits,
        image         = cfg.image,
        have_all_text = cfg.have_all_text or _('have all'),

        prepare       = wml_find_cfg(cfg, "prepare"),
        cleanup       = wml_find_cfg(cfg, "cleanup"),
        show_if       = wml_find_cfg(cfg, "show_if"),
        have_all_if   = wml_find_cfg(cfg, "have_all_if"),
        check_buyable = wml_find_cfg(cfg, "check_buyable"),
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
        speaker    = cfg.speaker,
        header     = cfg.header,

        indicators = wml_find_many_tags(cfg, "indicator"),

        prepare    = wml_find_cfg(cfg, "prepare"),
        cleanup    = wml_find_cfg(cfg, "cleanup"),
        prebuy     = wml_find_cfg(cfg, "prebuy"),
        postbuy    = wml_find_cfg(cfg, "postbuy"),
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
        elseif cc_shop.item[tag[1]] ~= nil then
            table.insert(items, cc_shop.item[tag[1]](tag[2]))
        end
    end

    return section
end

-------------------------------------------------------------------------------

local function maybe_fire_commands(commands)
    if commands ~= nil then
        wesnoth.fire("command", commands)
    end
end

local function maybe_check_condition(condition, if_nil)
    if condition ~= nil then
        return wesnoth.eval_conditional(condition)
    else
        return if_nil
    end
end

local function clear_variable(name)
    wesnoth.fire("clear_variable", { name = name })
end

-------------------------------------------------------------------------------

local function prepare_section(section)
    maybe_fire_commands(section.prepare)

    for i,item in ipairs(section.items) do
        maybe_fire_commands(item.prepare)
    end
end

local function check_item_status(item)
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
    elseif maybe_check_condition(item.have_all_if, false) then
        return 'unbuyable', item.have_all_text or _"have all"
    end

    local too_expensive = wesnoth.eval_conditional {
        { "variable", { 
            name = "cc_shop_gold",
            less_than = item.price 
        }}
    }

    if too_expensive then
        return 'too_expensive'
    end

    return 'buyable'
end

-------------------------------------------------------------------------------

local function show_section(section)
    local start = os.clock()

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

    local header = "<span foreground='gold'>Gold: $cc_shop_gold</span>"

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
                name = "cc_shop_location",
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
    
        local benefit_text=""

        if item.benefits ~= nil then
            benefit_text = string.format(
                "\n<span size='small' foreground='#aaaaaa'>%s</span>", 
                item.benefits)
        end

        -- Image
        --------

        local image = item.image and item.image .. (image_attr or "") or ""

        -- Command
        ----------

        local command = {}

        if item.prebuy ~= nil then
            table.insert(command, item.prebuy)
        end

        table.insert(command, item.command)

        if item.postbuy ~= nil then
            table.insert(command, item.postbuy)
        end

        -- Option
        ---------

        local status, reason = check_item_status(item)

        if status == 'buyable' then
            table.insert(message_cfg, { "option", {
                message=string.format(
                    "&%s=<span foreground='#88ff22'>%i gold</span>: %s%s",
                    image, item.price, name, benefit_text),

                { "command", {
                    { "gold", {
                        side = "$side_number",
                        amount = -item.price
                    }},

                    { "command", item.command }
                }}
            }})
        elseif status == 'too_expensive' then
            table.insert(message_cfg, { "option", {
                message=string.format(
                    "&%s=<span foreground='#ff4411'>%i gold</span>: %s%s",
                    image, item.price, name, benefit_text),
            }})
        elseif status == 'unbuyable' then
            table.insert(message_cfg, { "option", {
                message=string.format(
                    "&%s=<span foreground='#eecc22'>%s</span>: %s%s",
                    image, reason, name, benefit_text),
            }})
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
                    name = "cc_shop_location",
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

    -- Show the sections
    --------------------

    wesnoth.fire("message", message_cfg)
end

local function cleanup_section(section)
    for i,item in ipairs(section.items) do
        maybe_fire_commands(item.cleanup)
    end

    maybe_fire_commands(section.cleanup)
end

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
            if check_item_status(item) == 'buyable' then
                have_buyable = true
            end
        end
    end

    with_all(section, prepare_section)
    with_all(section, check_items)
    with_all(section, cleanup_section)

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
                        name = "cc_shop_location",
                        value = "r"
                    }}
                }}
            }}
        })
    end
    
    return true
end

function wesnoth.wml_actions.cc_shop(cfg_raw)

    parse_time = 0
    section_time = 0
    section_num = 0
    item_num = 0
    local start = os.clock()

    -- get __literal from cfg_raw and delocalize it
    -----------------------------------------------

    local cfg = delocalize_tag_cfg(cfg_raw.__literal)

    -- Parse the cc_shop tag
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
    wesnoth.set_variable("cc_shop_location", "r")

    while true do
        wesnoth.fire("store_gold", {
            side = "$side_number",
            variable = "cc_shop_gold"
        })

        local location = wesnoth.get_variable("cc_shop_location")

        if location == "e" then
            warn_still_byuable(root_section)

            location = wesnoth.get_variable("cc_shop_location")
            if location == "e" then
                break
            end
        end

        local section = section_by_id[location]

        prepare_section(section)
        show_section(section)
        cleanup_section(section)
    end

    clear_variable("cc_shop_location")
    clear_variable("cc_shop_gold")

    -- wesnoth.message(string.format("shop performance: %.2f sec parser, %.2f sec generator (avg %.2f per section (%i total), %.2f per item (%i total))", 
    --     parse_time, section_time, section_time / section_num, section_num, section_time / item_num, item_num))
end

>>
