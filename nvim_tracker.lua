local M = {}

local baselines = {}
local spool_dir = vim.fn.expand("~/.local/share/usertracker/spool")

-- Filtros de seguridad y ruido
local IGNORED_BUFTYPES = { nofile = true, terminal = true, help = true, prompt = true, quickfix = true }
local IGNORED_EXTENSIONS = { 
    env = true, pem = true, log = true, lock = true, 
    png = true, jpg = true, pdf = true, sqlite = true, db = true
}

local function is_ignorable_buffer(bufnr, buf_path)
    -- 1. Ignorar buffers especiales (no son archivos reales)
    if bufnr ~= 0 and vim.api.nvim_buf_is_valid(bufnr) then
        local buftype = vim.api.nvim_buf_get_option(bufnr, "buftype")
        if IGNORED_BUFTYPES[buftype] then return true end
    end
    
    -- 2. Ignorar rutas vacías
    if buf_path == "" then return true end
    
    -- 3. Ignorar extensiones sensibles o binarias
    local ext = vim.fn.fnamemodify(buf_path, ":e")
    if IGNORED_EXTENSIONS[ext] then return true end
    
    -- 4. Ignorar archivos dentro de .git o node_modules
    if string.match(buf_path, "/%.git/") or string.match(buf_path, "/node_modules/") then
        return true
    end
    
    return false
end

local function get_project_root(buf_path)
    local current_dir = vim.fn.fnamemodify(buf_path, ":h")
    while current_dir ~= "" and current_dir ~= "/" do
        if vim.fn.isdirectory(current_dir .. "/.git") == 1 or
           vim.fn.filereadable(current_dir .. "/package.json") == 1 then
            return current_dir
        end
        local parent = vim.fn.fnamemodify(current_dir, ":h")
        if parent == current_dir then break end
        current_dir = parent
    end
    return vim.fn.getcwd()
end

local function write_event(root, file_path, diff_str)
    if vim.fn.isdirectory(spool_dir) == 0 then
        vim.fn.mkdir(spool_dir, "p")
    end
    
    local timestamp = os.time()
    math.randomseed(timestamp + vim.fn.getpid())
    
    -- Codificamos la ruta en el nombre del archivo para que agy_hook filtre sin abrir el JSON
    local safe_root = root:gsub("/", "@@")
    local filename = string.format("%s/%s@@_%d_%d_%d.json", spool_dir, safe_root, timestamp, vim.fn.getpid(), math.random(10000, 99999))
    
    local json_data = {
        origin = "nvim",
        repo = root,
        file = file_path,
        diff = diff_str,
        timestamp = timestamp
    }
    
    local f = io.open(filename, "w")
    if f then
        f:write(vim.fn.json_encode(json_data))
        f:close()
    end
end

local function save_baseline(bufnr)
    if not vim.api.nvim_buf_is_valid(bufnr) then return end
    local buf_path = vim.api.nvim_buf_get_name(bufnr)
    if is_ignorable_buffer(bufnr, buf_path) or vim.fn.filereadable(buf_path) == 0 then return end
    
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    baselines[bufnr] = table.concat(lines, "\n")
end

local function generate_delta(bufnr)
    if not vim.api.nvim_buf_is_valid(bufnr) then return end
    local buf_path = vim.api.nvim_buf_get_name(bufnr)
    if is_ignorable_buffer(bufnr, buf_path) or vim.fn.filereadable(buf_path) == 0 then return end
    
    local new_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local new_content = table.concat(new_lines, "\n")
    local is_new = baselines[bufnr] == nil
    local old_content = baselines[bufnr] or ""
    
    if old_content == new_content and not is_new then return end
    -- Si es nuevo pero sigue vacio, lo ignoramos para no generar ruido, la creacion real se capta en Snacks
    if is_new and new_content == "" then return end
    
    local tmp_old = vim.fn.tempname()
    vim.fn.writefile(vim.split(old_content, "\n"), tmp_old)
    
    -- Usamos -uwB para ignorar espacios, tabulaciones y lineas vacias (ruido de prettier)
    local diff_cmd = {"diff", "-uwB", tmp_old, buf_path}
    local diff_output = {}
    
    vim.fn.jobstart(diff_cmd, {
        stdout_buffered = true,
        on_stdout = function(_, data)
            if data then
                for _, line in ipairs(data) do
                    table.insert(diff_output, line)
                end
            end
        end,
        on_exit = function()
            vim.fn.delete(tmp_old)
            local diff_str = table.concat(diff_output, "\n")
            if diff_str ~= "" then
                local root = get_project_root(buf_path)
                write_event(root, buf_path, diff_str)
            end
        end
    })
    
    baselines[bufnr] = new_content
end

local patched_state = {}

local function inject_snacks_hook()
    local ok_snacks, Snacks = pcall(require, "snacks")
    if ok_snacks and Snacks.input and type(Snacks.input.input) == "function" and not patched_state.input then
        patched_state.input = true
        local orig_input = Snacks.input.input
        Snacks.input.input = function(opts, on_confirm)
            local new_on_confirm = function(value)
                if on_confirm then on_confirm(value) end
                
                local is_add_prompt = false
                if type(opts) == "table" and type(opts.prompt) == "string" then
                    is_add_prompt = opts.prompt:lower():match("add a new file") ~= nil
                elseif type(opts) == "string" then
                    is_add_prompt = opts:lower():match("add a new file") ~= nil
                end
                
                -- Filtrar si es el prompt de creacion de explorer
                if value and not value:find("^%s$") and is_add_prompt then
                    local ok_picker, pickers = pcall(Snacks.picker.get)
                    if ok_picker and pickers and pickers[1] then
                        local dir = pickers[1]:dir()
                        local path = vim.fs.normalize(dir .. "/" .. value)
                        local is_file = value:sub(-1) ~= "/"
                        local type_str = is_file and "ARCHIVO" or "DIRECTORIO"
                        local diff_str = string.format("--- /dev/null\n+++ %s\n@@ -0,0 +1,1 @@\n+[%s CREADO VÍA SNACKS.EXPLORER]", path, type_str)
                        write_event(get_project_root(path), path, diff_str)
                    end
                end
            end
            return orig_input(opts, new_on_confirm)
        end
    end

    local ok_actions, actions = pcall(require, "snacks.explorer.actions")
    if ok_actions then
        -- Parche maestro para borrado (intercepta explorer_del a alto nivel)
        if type(actions.explorer_del) == "function" and not patched_state.del then
            patched_state.del = true
            local orig_del = actions.explorer_del
            actions.explorer_del = function(picker, ...)
                local paths = vim.tbl_map(function(i) return i.file or i.dir or i.text end, picker:selected({ fallback = true }))
                for _, path in ipairs(paths) do
                    if path and not is_ignorable_buffer(0, path) then
                        local root = get_project_root(path)
                        local type_str = vim.fn.isdirectory(path) == 1 and "DIRECTORIO" or "ARCHIVO"
                        local diff_str = string.format("--- %s\n+++ /dev/null\n@@ -1,1 +0,0 @@\n+[%s ELIMINADO VÍA SNACKS.EXPLORER]", path, type_str)
                        write_event(root, path, diff_str)
                    end
                end
                return orig_del(picker, ...)
            end
        end

        -- Backup parche trash por si se invoca directo
        if type(actions.trash) == "function" and not patched_state.trash then
            patched_state.trash = true
            local original_trash = actions.trash
            actions.trash = function(path, ...)
                if not is_ignorable_buffer(0, path) then
                    local root = get_project_root(path)
                    local diff_str = "--- " .. path .. "\n+++ /dev/null\n@@ -1,1 +0,0 @@\n-[ARCHIVO/DIRECTORIO ELIMINADO VÍA SNACKS.TRASH]"
                    write_event(root, path, diff_str)
                end
                return original_trash(path, ...)
            end
        end
    end

    local ok_rename, rename = pcall(require, "snacks.rename")
    if ok_rename and type(rename.rename_file) == "function" and not patched_state.rename then
        patched_state.rename = true
        local original_rename = rename.rename_file
        rename.rename_file = function(opts)
            local orig_on_rename = opts.on_rename
            opts.on_rename = function(new_path, old_path)
                if not is_ignorable_buffer(0, old_path) and not is_ignorable_buffer(0, new_path) then
                    local root = get_project_root(old_path)
                    -- Detectar en disco en caso de que ya se haya movido, asumiremos archivo por defecto
                    local type_str = vim.fn.isdirectory(new_path) == 1 and "DIRECTORIO" or "ARCHIVO"
                    local diff_str = string.format("--- %s\n+++ %s\n@@ -0,0 +1,1 @@\n+[%s RENOMBRADO/MOVIDO VÍA SNACKS A: %s]", old_path, new_path, type_str, new_path)
                    write_event(root, old_path, diff_str)
                end
                if orig_on_rename then orig_on_rename(new_path, old_path) end
            end
            return original_rename(opts)
        end
    end

    local ok_util, picker_util = pcall(require, "snacks.picker.util")
    if ok_util then
        if type(picker_util.copy) == "function" and not patched_state.copy then
            patched_state.copy = true
            local orig_copy = picker_util.copy
            picker_util.copy = function(paths, dir, ...)
                for _, p in ipairs(paths) do
                    local to = dir .. "/" .. vim.fn.fnamemodify(p, ":t")
                    local diff_str = string.format("--- /dev/null\n+++ %s\n@@ -0,0 +1,1 @@\n+[COPIADO VÍA SNACKS DESDE: %s]", to, p)
                    write_event(get_project_root(to), to, diff_str)
                end
                return orig_copy(paths, dir, ...)
            end
        end

        if type(picker_util.copy_path) == "function" and not patched_state.copy_path then
            patched_state.copy_path = true
            local orig_copy_path = picker_util.copy_path
            picker_util.copy_path = function(from, to, ...)
                local diff_str = string.format("--- /dev/null\n+++ %s\n@@ -0,0 +1,1 @@\n+[COPIADO VÍA SNACKS DESDE: %s]", to, from)
                write_event(get_project_root(to), to, diff_str)
                return orig_copy_path(from, to, ...)
            end
        end
    end
end

function M.setup()
    vim.api.nvim_create_autocmd({"BufReadPost", "FileChangedShellPost"}, {
        callback = function(args)
            save_baseline(args.buf)
        end
    })
    
    vim.api.nvim_create_autocmd("BufWritePost", {
        callback = function(args)
            generate_delta(args.buf)
        end
    })

    inject_snacks_hook()
    
    vim.api.nvim_create_autocmd("User", {
        pattern = "LazyLoad",
        callback = function(args)
            if args.data == "snacks.nvim" then
                inject_snacks_hook()
            end
        end
    })
end

return M
