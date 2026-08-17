local M = {}

local baselines = {}

local function get_project_root(buf_path)
    -- Traverse up to find .agents, .git, package.json, etc.
    local current_dir = vim.fn.fnamemodify(buf_path, ":h")
    while current_dir ~= "" and current_dir ~= "/" do
        if vim.fn.isdirectory(current_dir .. "/.agents") == 1 or
           vim.fn.isdirectory(current_dir .. "/.git") == 1 or
           vim.fn.filereadable(current_dir .. "/package.json") == 1 then
            return current_dir
        end
        local parent = vim.fn.fnamemodify(current_dir, ":h")
        if parent == current_dir then break end
        current_dir = parent
    end
    -- Fallback
    return vim.fn.getcwd()
end

local function save_baseline(bufnr)
    if vim.api.nvim_buf_is_valid(bufnr) then
        local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
        baselines[bufnr] = table.concat(lines, "\n")
    end
end

local function generate_delta(bufnr)
    if not vim.api.nvim_buf_is_valid(bufnr) then return end
    
    local buf_path = vim.api.nvim_buf_get_name(bufnr)
    if buf_path == "" or vim.fn.filereadable(buf_path) == 0 then return end
    
    local new_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local new_content = table.concat(new_lines, "\n")
    local old_content = baselines[bufnr] or ""
    
    if old_content == new_content then return end
    
    local tmp_old = vim.fn.tempname()
    vim.fn.writefile(vim.split(old_content, "\n"), tmp_old)
    
    -- Async diff to avoid freezing the UI on BufWritePost
    local diff_cmd = {"diff", "-u", tmp_old, buf_path}
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
            -- diff exits with 1 if there are differences, 0 if identical.
            if diff_str == "" then return end
            
            local root = get_project_root(buf_path)
            local agents_dir = root .. "/.agents"
            if vim.fn.isdirectory(agents_dir) == 0 then
                vim.fn.mkdir(agents_dir, "p")
            end
            
            local state_file = string.format("%s/nvim_state_%s.json", agents_dir, vim.fn.getpid())
            
            local json_data = {
                file = buf_path,
                diff = diff_str,
                timestamp = os.time()
            }
            
            local encoded = vim.fn.json_encode(json_data)
            local f = io.open(state_file, "a")
            if f then
                f:write(encoded .. "\n")
                f:close()
            end
        end
    })
    
    baselines[bufnr] = new_content
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
end

return M
