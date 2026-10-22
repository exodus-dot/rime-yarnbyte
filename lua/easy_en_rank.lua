--[[
easy_en_rank: 仅用于 Easy English 方案，按词频（lua/easy_en_rank.txt，由 tools/gen-easy-en-rank.ps1 生成）重排候选。
完全匹配输入的词排最前，其余按词频从高到低，词频相同则短词在前，再相同保持原顺序；无词频的词排最后。
其他方案不挂载本过滤器，候选顺序保持原样。
--]]

local easy_en_rank = {}

local freq -- 进程内只加载一次

local function load_freq()
    local t = {}
    local path = rime_api.get_user_data_dir() .. "/lua/easy_en_rank.txt"
    local f = io.open(path, "r")
    if not f then return t end
    for line in f:lines() do
        local word, w = line:match("^([^\t]+)\t(%d+)")
        if word then t[word] = tonumber(w) end
    end
    f:close()
    return t
end

function easy_en_rank.init(env)
    freq = freq or load_freq()
end

function easy_en_rank.func(input, env)
    local ctx_input = env.engine.context.input:lower()
    local items = {}
    for cand in input:iter() do
        local lower = cand.text:lower():gsub("%s+$", "") -- 上游 enhance_filter 会给候选补尾部空格
        items[#items + 1] = {
            cand = cand,
            idx = #items,
            exact = (lower == ctx_input) and 1 or 0,
            w = freq[lower] or 0,
            len = #lower,
        }
    end
    table.sort(items, function(a, b)
        if a.exact ~= b.exact then return a.exact > b.exact end
        if a.w ~= b.w then return a.w > b.w end
        if a.len ~= b.len then return a.len < b.len end
        return a.idx < b.idx
    end)
    for _, it in ipairs(items) do yield(it.cand) end
end

return { init = easy_en_rank.init, func = easy_en_rank.func }
