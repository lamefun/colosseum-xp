<<

-------------------------------------------------------------------------------
-- Tag transformations.
--
-- [shop]
--   tf_categories=cw -- eg. cw stands for Creep War, ms stands for Megaseum
--   
--   [item]
--     price=60
--     price_cw=100 -- Price will be 100 in creep war
--     tf_order=2 -- Will be after the next item
--   [/item]
--
--   [item]
--     tf_exclude=cw,ms -- Excluded from Creep War and Megaseum
--     tf_order=1 -- Will be before the previous item
--   [/item]
-- [/shop]
--
-------------------------------------------------------------------------------

local function comma_split(str)
    local t = {}
    for v in string.gmatch(str, "[^,]+") do
        table.insert(t, v)
    end
    return t 
end

function cc.transform(cfg)
    local function transform(cfg, parent_categories)
        local categories = parent_categories

        -- Own categories

        if cfg.tf_categories ~= nil then
            categories = comma_split(cfg.tf_categories)
            for i,s in ipairs(categories) do
                categories[s] = true
            end
        end
        
        -- Exclusion

        if cfg.tf_exclude ~= nil then
            local exclude = comma_split(cfg.tf_exclude)
            for i,s in ipairs(exclude) do
                if categories[s] ~= nil then
                    return false
                end
            end
        end

        -- Inclusion

        if cfg.tf_include ~= nil then
            local include = comma_split(cfg.tf_include)
            local included = false
            
            for i,s in ipairs(exclude) do
                if categories[s] ~= nil then
                    included = true
                    break
                end
            end

            if not included then
                return false
            end
        end
        
        -- Attribute overrides

        for i,category in ipairs(categories) do
            local postfix = '_' .. category
            for k,v in pairs(cfg) do
                if type(k) == 'string' and cc.ends_with(k, postfix) then
                    local name = string.sub(k, 1, string.len(k) - string.len(postfix))
                    cfg[name] = v
                end
            end
        end

        -- Nested tags

        local i=1
        local reordered={}
        while i <= #cfg do
            local sub_cfg = cfg[i][2]
            if not transform(sub_cfg, categories) then
                table.remove(cfg, i)
            elseif sub_cfg.tf_order ~= nil then
                table.insert(reordered, cfg[i])
                table.remove(cfg, i)
            else
                i = i + 1
            end
        end

        -- Re-ordering
        table.sort(reordered, function(a, b)
            local a_order = a[2].tf_order or 0
            local b_order = b[2].tf_order or 0
            return a_order < b_order
        end)
        
        for i = #reordered, 1, -1 do
            table.insert(cfg, 1, reordered[i])
        end
        
        return true
    end

    transform(cfg, {})
end

>>
