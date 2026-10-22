-- 候选高亮时按标点键：上屏候选（去掉 easy_en_enhance 自动补的尾部空格）并直接跟上该标点。
-- 标点集合由 easy_en/no_space_punct 配置，默认 ",.;:?!)]}\""；不含 ' - =（分隔符/翻页键）。

local M = {}

function M.init(env)
    local cfg = env.engine.schema.config
    local s = cfg:get_string("easy_en/no_space_punct") or ',.;:?!)]}"'
    env.puncts = {}
    for i = 1, #s do env.puncts[s:sub(i, i)] = true end
end

function M.func(key, env)
    local ctx = env.engine.context
    if not ctx:has_menu() or key:release() or key:ctrl() or key:alt() then return 2 end
    local code = key.keycode
    if code < 0x21 or code > 0x7e then return 2 end
    local ch = string.char(code)
    if not env.puncts[ch] then return 2 end
    local cand = ctx:get_selected_candidate()
    if not cand then return 2 end
    env.engine:commit_text((cand.text:gsub("%s+$", "")) .. ch)
    ctx:clear()
    return 1
end

return { init = M.init, func = M.func }
