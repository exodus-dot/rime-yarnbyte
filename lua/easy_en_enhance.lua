local is_split_sentence
local wordninja_split

local function capture(cmd)
   local f = assert(io.popen(cmd, 'r'))
   local s = assert(f:read('*a'))
   f:close()
   return s
end

local function memory_callback(memory, commit)
   for i, dictentry in ipairs(commit:get()) do
      memory:update_userdict(dictentry, 1, "")
   end
end

-- [yarnbyte] 纯 Lua 拆词：用 lua/easy_en_rank.txt 的词频做最小代价切分，不依赖 wordninja 外部程序
local split_cost, split_maxlen
local function load_split_cost()
   split_cost, split_maxlen = {}, 0
   local min_freq = { [2] = 40, [3] = 20 }
   local f = io.open(rime_api.get_user_data_dir() .. "/lua/easy_en_rank.txt", "r")
   if not f then return end
   for line in f:lines() do
      local w, n = line:match("^([a-z]+)\t(%d+)")
      n = tonumber(n)
      if w and n >= 10 and #w > 1 and (#w > 3 or n >= min_freq[#w]) then
         split_cost[w] = 4 - math.log(n / 100)
         if #w > split_maxlen then split_maxlen = #w end
      end
   end
   f:close()
   split_cost["a"] = 4 - math.log(0.9)
   split_cost["i"] = split_cost["a"]
end

local function builtin_split(sentence)
   if not split_cost then load_split_cost() end
   local s = sentence:lower()
   local n = #s
   if n < 2 or n > 60 or not s:match("^[a-z]+$") then return sentence end
   local best, prev = { [0] = 0 }, {}
   for i = 1, n do
      best[i] = math.huge
      for j = math.max(0, i - split_maxlen), i - 1 do
         local c = split_cost[s:sub(j + 1, i)]
         if c and best[j] + c < best[i] then
            best[i] = best[j] + c
            prev[i] = j
         end
      end
   end
   if best[n] == math.huge then return sentence end
   local parts, i = {}, n
   while i > 0 do
      table.insert(parts, 1, sentence:sub(prev[i] + 1, i))
      i = prev[i]
   end
   return table.concat(parts, " ")
end

local function init(env)
   env.mem = Memory(env.engine,env.engine.schema)
   env.mem:memorize(function(commit) memory_callback(env.mem, commit) end)

   is_split_sentence = env.engine.schema.config:get_bool('easy_en/split_sentence')
   if not is_split_sentence then
      wordninja_split = function(sentence)
         return sentence
      end
      return
   end

   if env.engine.schema.config:get_bool('easy_en/use_builtin_split') then
      wordninja_split = builtin_split
      return
   end

   local use_wordninja_rs_lua_module = env.engine.schema.config:get_bool('easy_en/use_wordninja_rs_lua_module')
   local use_wordninja_rs = env.engine.schema.config:get_bool('easy_en/use_wordninja_rs')
   local use_wordninja_py = env.engine.schema.config:get_bool('easy_en/use_wordninja_py')
   if (not use_wordninja_rs_lua_module) and (not use_wordninja_rs) and (not use_wordninja_py) then
      -- default use wordninja_rs_lua_module
      use_wordninja_rs_lua_module = true
   end

   if use_wordninja_rs_lua_module then
      local wordninja_rs_lua_module_path = env.engine.schema.config:get_string('easy_en/wordninja_rs_lua_module_path')
      if not string.find(package.cpath, wordninja_rs_lua_module_path, 1, true) then
         package.cpath = package.cpath .. ";" .. wordninja_rs_lua_module_path
      end
      wordninja_split = require("wordninja").split
      return
   end

   if use_wordninja_rs then
      local wordninja_rs_path = env.engine.schema.config:get_string('easy_en/wordninja_rs_path')
      wordninja_split = function(sentence)
         return capture(wordninja_rs_path .. " -n '" .. sentence .. "'")
      end
      return
   end

   if use_wordninja_py then
      wordninja_split = function(sentence)
         return capture([[python -c "import sys; import wordninja; sys.stdout.write(' '.join(wordninja.split(']] .. sentence .. [[')))"]])
      end
      return
   end
end

local function fini(env)
   env.mem:disconnect()
end

local function new_dict_cand(mem, start, _end, text, custom_code)
   dictentry = DictEntry()
   dictentry.text = text
   dictentry.custom_code = custom_code
   ph = Phrase(mem, "word", start, _end, dictentry)

   return ShadowCandidate(ph:toCandidate(), "word", text .. " ", "📝", "")
end

local function is_in_dict(mem, text)
   return mem:user_lookup(text, false) or mem:dict_lookup(text, false, 1)
end

local function enhance_filter(input, env)
   for cand in input:iter() do
      if (cand.comment:find("☯")) then
         -- show splited sentence
         -- don't need to save splited sentence into dict
         if (is_split_sentence) then
            sentence = wordninja_split(cand.text)
            lower_sentence = string.lower(sentence)

            if (not (lower_sentence == sentence)) then
               yield(Candidate("sentence", cand.start, cand._end, lower_sentence .. " ", "💡"))
            end

            yield(Candidate("sentence", cand.start, cand._end, sentence .. " ", "💡"))
         end

         composition = env.engine.context.composition
         segmentation = composition:toSegmentation()
         custom_code = segmentation.input

         if (not (cand.text == custom_code)) then
            yield(new_dict_cand(env.mem, cand.start, cand._end, custom_code, custom_code))
         end
         yield(new_dict_cand(env.mem, cand.start, cand._end, cand.text, custom_code))
      else
         yield(UniquifiedCandidate(cand, "word", cand.text .. " ", cand.comment))
      end
   end
end

return { enhance_filter = { init = init, fini = fini, func = enhance_filter} }
