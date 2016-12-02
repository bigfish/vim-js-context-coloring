"plugin to add javascript scope-coloring
"Version: 0.0.8
"Author: David Wilhelm <dewilhelm@gmail.com>
"
"Note: highlights function scopes in JavaScript
"
" Only do this when not done yet for this buffer
if exists("b:did_jscc_ftplugin")
  finish
endif

setlocal iskeyword+=$

let b:did_jscc_ftplugin = 1
let b:scope_groups = []

let s:cli_cmd = 'jscc-cli'
let s:server_cmd = 'jscc-server.js'
let s:cli_options = ''

" check options to send as CLI params
if !exists('g:js_context_colors_jsx')
    let g:js_context_colors_jsx = 0
endif

"however, if current buffer file extension is .jsx
"turn on jsx flag
let b:file_ext = expand('%:e')
if b:file_ext == "jsx"
    let g:js_context_colors_jsx = 1
endif

if g:js_context_colors_jsx
    let s:cli_options .= ' --jsx'
endif

if !exists('g:js_context_colors_block_scope')
    let g:js_context_colors_block_scope = 0
endif

if g:js_context_colors_block_scope
    let s:cli_options .= ' --block-scope'
endif

if !exists('g:js_context_colors_block_scope_with_let')
    let g:js_context_colors_block_scope_with_let = 0
endif

if g:js_context_colors_block_scope_with_let
    let s:cli_options .= ' --block-scope-with-let'
endif

if !exists('g:js_context_colors_highlight_function_names')
    let g:js_context_colors_highlight_function_names = 0
endif

if g:js_context_colors_highlight_function_names
    let s:cli_options .= ' --highlight-function-names'
endif


"revert to old cli if es5 option is given
if !exists('g:js_context_colors_es5')
    let g:js_context_colors_es5 = 0
endif

if g:js_context_colors_es5
    let s:cli_cmd = 'jscc-cli-legacy'
endif

if !exists('g:js_context_colors_babel')
    let g:js_context_colors_babel = 0
endif

if g:js_context_colors_babel
    let s:cli_options .= ' --babel'
endif

let s:region_count = 1

syntax case match

"set default options if no provided value
if !exists('g:js_context_colors_enabled')
    let g:js_context_colors_enabled = 1
endif

if !exists('g:js_context_colors_usemaps')
    let g:js_context_colors_usemaps = 1
endif

if !exists('g:js_context_colors_colorize_comments')
    let g:js_context_colors_colorize_comments = 0
endif

if !exists('g:js_context_colors_fold')
    let g:js_context_colors_fold = 1
endif

if !exists('g:js_context_colors_foldlevel')
    let g:js_context_colors_foldlevel = 9
endif

if !exists('g:js_context_colors_show_error_message')
    let g:js_context_colors_show_error_message = 0
endif

if !exists('g:js_context_colors_debug')
    let g:js_context_colors_debug = 0
endif

if !exists('g:js_context_colors_allow_jsx_syntax')
    let g:js_context_colors_allow_jsx_syntax = 0
endif
let s:max_levels = 10

if !exists('g:js_context_colors_server_port')
    let g:js_context_colors_server_port = 6969
endif
let s:jscc_server_url = 'localhost:' . g:js_context_colors_server_port

if g:js_context_colors_es5
    let s:jscc = expand('<sfile>:p:h') . '/../bin/' . s:cli_cmd
else
    let s:jscc = expand('<sfile>:p:h') . '/../bin/' . s:cli_cmd . s:cli_options
endif

let s:jscc_server = expand('<sfile>:p:h') . '/../bin/' . s:server_cmd . s:cli_options

"parse functions
function! Strip(input_string)
    return substitute(a:input_string, '^\s*\(.\{-}\)\s*$', '\1', '')
endfunction

"following functions are used for debugging
function! Warn(msg)
    echohl Error | echom a:msg
    echohl Normal
endfunction

function! IsPos(pos)
    if len(a:pos) != 2
        return 0
    endif
    if type(a:pos[0]) != type(0)
        return 0
    endif
    if type(a:pos[0]) < 0
        return 0
    endif
    if type(a:pos[1]) != type(0)
        return 0
    endif
    if type(a:pos[1]) < 0
        return 0
    endif

    return 1
endfunction

function! GetPosFromOffset(offset)

    "normalize byte count for Vim (first byte is 1 in Vim)
    let offset = a:offset + 1
    if offset < 0
        call Warn('offset cannot be less than 0: ' . string(offset))
    endif

    let line = byte2line(offset)
    "the above function interprets the last line as -1
    "this needs to be replaced with the actual last line number
    if line == -1
        let line = line('$')
    endif
    let line_start_offset = line2byte(line)
    "first col is 1 in Vim
    let col = (offset - line_start_offset) + 1
    let pos = [line, col]
    "if !IsPos(pos)
    "Warn('invalid pos result in GetPosFromOffset()' . string(pos))
    "endif
    return pos
endfunction

let s:jscc_highlight_groups_defined = 0

function! JSCC_DefineSyntaxGroups()

    "define JavaScript syntax groups -- all syntax is cleared when
    "colorizing is done, so they must be redefined
    syntax keyword javaScriptCommentTodo    TODO FIXME XXX TBD contained
    syntax region  javaScriptLineComment    start=+\/\/+ end=+$+ keepend contains=javaScriptCommentTodo
    syntax region  javaScriptLineComment    start=+^\s*\/\/+ skip=+\n\s*\/\/+ end=+$+ keepend contains=javaScriptCommentTodo fold
    syntax region  javaScriptComment        start="/\*"  end="\*/" contains=javaScriptCommentTodo fold

    syntax cluster jsComment contains=javaScriptComment,javaScriptLineComment

    "allow highlighting of vars inside strings,jsx regions
    "TODO: fix issue where quote characters inside regex literals breaks highlighting

    "for lev in range(s:max_levels)
        "exe 'syntax region  javaScriptStringD_'. lev .'        start=+"+  skip=+\\\\\|\\$"+  end=+"+ keepend'
        "exe "syntax region  javaScriptStringS_". lev ."        start=+'+  skip=+\\\\\|\\$'+  end=+'+ keepend"
        "exe "syntax region  javaScriptTemplate_". lev ."        start=+`+  skip=+\\\\\|\\$'\"+  end=+`+ keepend"

        "if g:js_context_colors_jsx
            " Highlight JSX regions as XML; recursively match.
            "exe "syn region jsxRegion_" . lev . " contains=jsxRegion,javaScriptStringD_". lev .",javaScriptStringS_" . lev ." start=+<\\@<!<\\z([a-zA-Z][a-zA-Z0-9:\\-.]*\\)+ skip=+<!--\\_.\\{-}-->+ end=+</\\z1\\_\\s\\{-}>+ end=+/>+ keepend extend"
        "endif

        "exe 'hi link javaScriptStringS_' . lev . ' JSCC_Level_' . lev
        "exe 'hi link javaScriptStringD_' . lev . ' JSCC_Level_' . lev
        "exe 'hi link javaScriptTemplate_' . lev . ' JSCC_Level_' . lev

        "if g:js_context_colors_jsx
            "exe 'hi link jsxRegion_' . lev . ' JSCC_Level_' . lev
        "endif

    "endfor

endfunction

"define highlight groups dynamically
function! JSCC_DefineHighlightGroups()

    colors js_context_colors

    let s:jscc_highlight_groups_defined = 1
endfunction

function! JSCC_ClearScopeSyntax()
    "clear previous scope syntax groups
    syn clear

    "if len(b:scope_groups)
        "for grp in b:scope_groups
            "exe "syntax clear " . join(b:scope_groups, " ")
        "endfor
        "let b:scope_groups = []
    "endif
endfunction

function! GetBufferText()
    "obtain contents of buffer
    let buflines = getline(1, '$')

    "replace hashbangs (in node CLI scripts)
    let linenum  = 0
    for bline in buflines
        if match(bline, '#!') == 0
            "replace #! with // to prevent parse errors
            "while not throwing off byte count
            let buflines[linenum] = '//' . strpart(bline, 2)
            break
        endif
        let linenum += 1
    endfor
    "fix offset errors caused by windows line endings
    "since 'buflines' does NOT return the line endings
    "we need to replace them for unix/mac file formats
    "and for windows we replace them with a space and \n
    "since \r does not work in node on linux, just replacing
    "with a space will at least correct the offsets
    if &ff == 'unix' || &ff == 'mac'
        let buftext = join(buflines, "\n")
    elseif &ff == 'dos'
        let buftext = join(buflines, " \n")
    else
        echom 'unknown file format' . &ff
        let buftext = join(buflines, "\n")
    endif

    return buftext

endfunction

function! JSCC_Colorize()

    "bail if not a js filetype
    if stridx(&ft, 'javascript') != 0
        return
    endif

    "if new file, empty, return
    if (line('$') == 1 && getline(1) == '')
        return
    endif

    "use server channel if its open
    if exists('g:jscc_channel') && ch_status(g:jscc_channel) == "open"

        let buftext = GetBufferText()

        "noop if empty string
        if Strip(buftext) == ''
            return
        endif

	      call ch_sendraw(g:jscc_channel, buftext . '
                    \', {'callback': 'JSCC_Colorize2'})

    elseif has('job')
        "if the server job doesn't work, this method can be used..
        "start job to get colors asynchronously with input of current buffer
        "if exists('g:jscc_job')
            "echom job_status(g:jscc_job)
        "else
            "let g:jscc_job = job_start(s:jscc, {"in_io": "buffer", "in_name": bufname('%'), "out_mode": "nl", "out_cb": "JSCC_Colorize2", "err_cb": "JSCC_ColorizeError"})
        "endif
    else

        let buftext = GetBufferText()

        "noop if empty string
        if Strip(buftext) == ''
            return
        endif

        "call parser synchronously
        "ignore errors from shell command to prevent distracting user
        "syntax errors should be caught by a lint program
        try
            let colordata_result = system(s:jscc, buftext)

            call JSCC_Colorize2(null, colordata_result)
        catch

            if g:js_context_colors_show_error_message || g:js_context_colors_debug
                echom "Syntax Error [JSContextColors]"
            endif

            if g:js_context_colors_debug
                echom colordata_result
            endif

        endtry

    endif

endfunction

function! JSCC_ColorizeError(channel, err)

    if g:js_context_colors_show_error_message || g:js_context_colors_debug
        echom "Syntax Error [JSContextColors]"
    endif

    if g:js_context_colors_debug
        echom a:err
    endif

endfunction

function! JSCC_Colorize2(channel, colordata)

    "colordata is a string, in JavaScript/Vim format
    let colordata_result = a:colordata

    "if we are in vim 8, it is a channel response that can be decoded by js_decode
    if has('job')
        let colordata = js_decode(a:colordata)
    else
        let colordata = eval(a:colordata)
    endif

    call JSCC_ClearScopeSyntax()

    let s:region_count = 0

    let s:scope_level_clusters = {}

    if !g:js_context_colors_colorize_comments
        call JSCC_DefineSyntaxGroups()
    endif

    if !s:jscc_highlight_groups_defined
        call JSCC_DefineHighlightGroups()
    endif

    let scopes = colordata['scopes']


        for scope in scopes

            "use offset from end to normalize 3 element and 2 element ranges
            let start_pos = GetPosFromOffset(scope[1])
            let end_pos = GetPosFromOffset(scope[2])

            let group_name = 'Level' . scope[0]
            let level = scope[0]

            let enclosed = scope[3]
            let enclosed_groups = []

            "create unique scope syntax group name
            let s:region_count = s:region_count + 1
            let scope_group = group_name . s:region_count

            "create a scope level cluster or add scope to existing one
            let scope_cluster = 'ScopeLevelCluster_' . level

            if has_key(s:scope_level_clusters, scope_cluster)
                exe 'syntax cluster ' . scope_cluster .' add=' . scope_group
            else
                exe 'syntax cluster ScopeLevelCluster_' . level . ' contains=' . scope_group
                let s:scope_level_clusters[scope_cluster] = 1
            endif

            "handle vars
            for var in keys(enclosed)

                let var_level = enclosed[var]

                if var_level < level

                    if var_level == -1
                        let var_syntax_group = 'JSCC_UndeclaredGlobal'
                    else
                        let var_syntax_group = 'JSCC_Level_' . var_level . '_' . tr(var, '$', 'S')
                    endif

                    exe "syn match ". var_syntax_group . ' /\_[^.$[:alnum:]_]\zs' . var . "\\>\\(\\s*\\:\\)\\@!/ display contained containedin=" . scope_group

                    "also match ${var} inside template strings
                    exe "syn match ". var_syntax_group . ' /${\zs' . var . "\\(}\\)\\@=\\(\\s*\\:\\)\\@!/ display contained containedin=javaScriptTemplate_" . level

                    "also matcth {{var}} inside strings, eg handlebars
                    exe "syn match ". var_syntax_group . ' /{{\zs' . var . "\\(}}\\)\\@=\\(\\s*\\:\\)\\@!/ display contained containedin=javaScriptStringD_" . level . ",javaScriptStringS_" . level

                    "match {var} in jsx
                    if g:js_context_colors_jsx
                        exe "syn match ". var_syntax_group . ' /\<' . var . "\\>\\(\\s*\\:\\)\\@!/ display contained containedin=jsxRegion_" . level
                    endif

                    if var_level != -1
                        exe 'hi link ' . var_syntax_group . ' JSCC_Level_' . var_level
                    endif

                    call add(enclosed_groups, var_syntax_group)
                endif

            endfor

            let contains = "contains=@jsComment," . (g:js_context_colors_allow_jsx_syntax ? "jsxRegion," : "")
                        \. "javaScriptStringS_" . level . ",javaScriptStringD_" . level . ",javaScriptTemplate_" . level . ",javaScriptProp,@ScopeLevelCluster_" . (level + 1)

            if len(enclosed_groups)
            endif

            let cmd = "syn region ". scope_group . " start='\\%" . start_pos[0] ."l\\%". start_pos[1] .
                        \"c' end='\\%" . end_pos[0] . "l\\%" . end_pos[1] .
                        \"c' " . contains . " fold"
            exe cmd

            exe 'hi link ' . scope_group . ' ' . 'JSCC_Level_' . level

            call add(b:scope_groups, scope_group)

        endfor

        if g:js_context_colors_debug
            echom colordata_result
        endif
    "ensure syntax highlighting is fully applied
    syntax sync fromstart

endfunction

function! JSCC_Enable()

    if !s:jscc_highlight_groups_defined
        call JSCC_DefineHighlightGroups()
    endif

    if g:js_context_colors_fold
        setlocal foldmethod=syntax
        exe "setlocal foldlevel=" . g:js_context_colors_foldlevel
    endif

    try
        augroup JSContextColorAug
            "remove if added previously, but only in this buffer
            au! TextChanged,InsertLeave <buffer>
            au! TextChanged,InsertLeave <buffer> :JSContextColor
        augroup END

    "if < vim 7.4 TextChanged events are not
    "available and will result in error E216
    catch /^Vim\%((\a\+)\)\=:E216/

            "use different events to trigger update in Vim < 7.4
            augroup JSContextColorAug
                au! InsertLeave <buffer>
                au! InsertLeave <buffer> :JSContextColor
            augroup END

    endtry

    syntax clear

    "try to connect to server with a channel
    let connected = JSCC_OpenChannel(0)
    let tries = 1

    "start server job if unable to connect
    if !connected

        call JSCC_StartServer()

        while !connected
            let connected = JSCC_OpenChannel(100)
            let tries += 1
            if tries > 20
                break
            endif
        endwhile

    endif

    if !connected
        echom 'Failed to connect to jscc server, status: ' .  ch_status(g:jscc_channel)
    endif

    :JSContextColor

endfunction

"returns 1 if successful, 0 if not
function! JSCC_OpenChannel(wait)
    let g:jscc_channel = ch_open(s:jscc_server_url, {'mode': 'nl',
                \'waittime': a:wait,
                \'callback': 'JSCC_Colorize2'})
    if ch_status(g:jscc_channel) == 'fail' || ch_status(g:jscc_channel) == 'closed'
        return 0
    else
        return 1
    endif
endfunction

function! JSCC_StartServer()
	  let s:jscc_server_job = job_start(["/bin/sh", "-c", "node " . s:jscc_server])
endfunction

function! JSCC_Disable()
    "clear autocommands
    try
        augroup JSContextColorAug
            au! InsertLeave,TextChanged <buffer>
        augroup END

    catch /^Vim\%((\a\+)\)\=:E216/

        augroup JSContextColorAug
            au! InsertLeave <buffer>
        augroup END
    endtry

    call JSCC_ClearScopeSyntax()
    syntax enable

    let s:jscc_highlight_groups_defined = 0
endfunction

function! JSCC_Toggle()
    if g:js_context_colors_enabled
        let g:js_context_colors_enabled = 0
        call JSCC_Disable()
    else
        let g:js_context_colors_enabled = 1
        call JSCC_Enable()
    endif
endfunction

"define user commands
"command! -range=% -nargs=0 JSContextColor <line1>,<line2>:call JSCC_Colorize()
command! JSContextColor call JSCC_Colorize()

command! JSContextColorToggle call JSCC_Toggle()

command! JSContextColorUpdate call JSCC_DefineHighlightGroups()

"always create color highlight groups in case of direct calls to :JSContextColor
:JSContextColorUpdate

if g:js_context_colors_usemaps
    if !hasmapto('<Plug>JSContextColor')
        "mnemonic (h)ighlight
        nnoremap <buffer> <silent> <localleader>h :JSContextColor<CR>
    endif

    if !hasmapto('<Plug>JSContextColorToggle')
        "mnemonic (t)oggle
        nnoremap <buffer> <silent> <localleader>t :JSContextColorToggle<CR>
    endif
endif
