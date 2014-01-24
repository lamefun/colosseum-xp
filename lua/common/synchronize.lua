<<

function cc.synchronize_choice(fn, ai_fn)
    local fn_wrapper = nil
    local ai_fn_wrapper = nil

    if fn ~= nil then
        fn_wrapper = function()
            return { value = cc.tojson(fn()) }
        end
    end

    if ai_fn ~= nil then
        ai_fn_wrapper = function()
            return { value = cc.tojson(ai_fn()) }
        end
    end

    local result = wesnoth.synchronize_choice(fn_wrapper, ai_fn_wrapper)

    return cc.fromjson(result.value)
end

function wesnoth.wml_actions.cc_sync_random(cfg_raw)
    local cfg = cfg_raw.__parsed
    wesnoth.set_variable(cfg.variable, math.floor(math.random(cfg.start, cfg.finish) + 0.5))
end

>>
