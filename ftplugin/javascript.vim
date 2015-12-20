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
let b:did_jscc_ftplugin = 1

let s:cli_cmd = 'jscc-cli'

" check options to send as CLI params
if !exists('g:js_context_colors_jsx')
    let g:js_context_colors_jsx = 0
endif

" SET FLAGS IF NOT SET
"however, if current buffer file extension is .jsx
"turn on jsx flag
let b:file_ext = expand('%:e')
if b:file_ext == "jsx"
    let g:js_context_colors_jsx = 1
endif

if g:js_context_colors_jsx 
    let s:cli_cmd .= ' --jsx'
endif

if !exists('g:js_context_colors_block_scope')
    let g:js_context_colors_block_scope = 0
endif

if g:js_context_colors_block_scope 
    let s:cli_cmd .= ' --block-scope'
endif

if !exists('g:js_context_colors_block_scope_with_let')
    let g:js_context_colors_block_scope_with_let = 0
endif

if !exists('g:js_context_colors_highlight_function_names')
    let g:js_context_colors_highlight_function_names = 0
endif

if g:js_context_colors_highlight_function_names
    let s:cli_cmd .= ' --highlight-function-names'
endif

if g:js_context_colors_block_scope_with_let 
    let s:cli_cmd .= ' --block-scope-with-let'
endif

"revert to old cli if es5 option is given
if !exists('g:js_context_colors_es5')
    let g:js_context_colors_es5 = 0
endif

if g:js_context_colors_es5
    let s:cli_cmd = 'jscc-cli-legacy'
endif

let s:jscc = expand('<sfile>:p:h') . '/../bin/' . s:cli_cmd

let s:region_count = 1

syntax case match

setlocal iskeyword+=$

"set default options if no provided value
if !exists('g:js_context_colors_enabled')
    let g:js_context_colors_enabled = 1
endif

"turn off by default
if !exists('g:js_context_colors_usemaps')
    let g:js_context_colors_usemaps = 0
endif

if !exists('g:js_context_colors_colorize_comments')
    let g:js_context_colors_colorize_comments = 0
endif

"default fold to off as it has a performance hit on larger files when setting foldlevel
if !exists('g:js_context_colors_fold')
    let g:js_context_colors_fold = 0
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

if !exists('g:js_context_colors_theme')
    let g:js_context_colors_theme = 'js_context_colors'
endif

let s:max_levels = 10

"used by neovim
function! JSCC_GetConfig()
    "construct JSON
    let json =  "{".
                \'"jsx":' . g:js_context_colors_jsx . "," .
                \'"block_scope":' . g:js_context_colors_block_scope . "," .
                \'"block_scope_with_let":'  . g:js_context_colors_block_scope_with_let . "," .
                \'"highlight_function_names":' . g:js_context_colors_highlight_function_names . "," .
                \'"es5":' . g:js_context_colors_es5 . "," .
                \'"enabled":' . g:js_context_colors_enabled . "," .
                \'"debug":' . g:js_context_colors_debug . "}"
    "echom json
    return json

endfunction

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
    
    for lev in range(s:max_levels)
        exe 'syntax region  javaScriptStringD_'. lev .'        start=+"+  skip=+\\\\\|\\$"+  end=+"+ keepend'
        exe "syntax region  javaScriptStringS_". lev ."        start=+'+  skip=+\\\\\|\\$'+  end=+'+ keepend"
        exe "syntax region  javaScriptTemplate_". lev ."        start=+`+  skip=+\\\\\|\\$'\"+  end=+`+ keepend"

        if g:js_context_colors_jsx 
             "Highlight JSX regions as XML; recursively match.
            exe "syn region jsxRegion_" . lev . " contains=jsxRegion,javaScriptStringD_". lev .",javaScriptStringS_" . lev ." start=+<\\@<!<\\z([a-zA-Z][a-zA-Z0-9:\\-.]*\\)+ skip=+<!--\\_.\\{-}-->+ end=+</\\z1\\_\\s\\{-}>+ end=+/>+ keepend extend"
        endif

        exe 'hi link javaScriptStringS_' . lev . ' JSCC_Level_' . lev
        exe 'hi link javaScriptStringD_' . lev . ' JSCC_Level_' . lev
        exe 'hi link javaScriptTemplate_' . lev . ' JSCC_Level_' . lev

        if g:js_context_colors_jsx 
            exe 'hi link jsxRegion_' . lev . ' JSCC_Level_' . lev
        endif

    endfor

endfunction

"define highlight groups dynamically
function! JSCC_DefineHighlightGroups()

    exe "colors " . g:js_context_colors_theme

    let s:jscc_highlight_groups_defined = 1
endfunction



"vim version -- use external CLI command to get colordata
function! JSCC_Colorize()

    doautocmd User jscc.colorize

endfunction 

function! JSCC_GetBufferText()

    let buflines = getline(1, '$')
    let buftext = ""

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
    endif

    "noop if empty string
    if Strip(buftext) == ''
        return ""
    endif

    return buftext

endfunction

"called asynchronously by neovim node host
function! JSCC_Colorize2(colordata_result)

    "bail if not a js filetype
    if &ft != 'javascript'
        return
    endif

    let s:region_count = 0

    syntax clear

    let s:scope_level_clusters = {}

    if !g:js_context_colors_colorize_comments
        call JSCC_DefineSyntaxGroups()
    endif

    if !s:jscc_highlight_groups_defined
        call JSCC_DefineHighlightGroups()
    endif


    "ignore errors from shell command to prevent distracting user
    "syntax errors should be caught by a lint program
    try

        let colordata = eval(a:colordata_result)

        "if g:js_context_colors_debug
            "echom "result: " . a:colordata_result
        "endif

        let scopes = colordata.scopes
        "let symbols = colordata.symbols

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

            let contains = "contains=@jsComment,javaScriptStringS_" . level . ",javaScriptStringD_" . level . ",javaScriptTemplate_" . level . ",javaScriptProp,@ScopeLevelCluster_" . (level + 1)

            if len(enclosed_groups)
                let contains .= ',' . join(enclosed_groups, ',')
            endif

            let cmd = "syn region ". scope_group . " start='\\%" . start_pos[0] ."l\\%". start_pos[1] .
                        \"c' end='\\%" . end_pos[0] . "l\\%" . end_pos[1] .
                        \"c' " . contains . " fold"
            exe cmd

            exe 'hi link ' . scope_group . ' ' . 'JSCC_Level_' . level

        endfor

    catch

        if g:js_context_colors_show_error_message || g:js_context_colors_debug
            echom "Syntax Error [JSContextColors]"
        endif

    endtry

    "re-highlight eslint highlighting if we find eslint errors
    if b:did_eslint_ftplugin && len(b:lint_errors)
        call ShowEslintErrorHighlighting()
    endif

    "ensure syntax highlighting is fully applied
    syntax sync fromstart

endfunction

"let b:initial_load = 1

function! JSCC_Enable()

    let g:js_context_colors_enabled = 1

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
            au! InsertLeave,TextChanged <buffer> 
            au! InsertLeave,TextChanged <buffer> :JSContextColor
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

    syn clear

    "reinitialize syntax for this buffer
    "since g:js_context_colors_enabled is 0
    "it will use whatever syntax is first found in runtimepath
    runtime! syntax/javascript.vim

    let s:jscc_highlight_groups_defined = 0

endfunction

function! JSCC_Toggle()
    if g:js_context_colors_enabled
        let g:js_context_colors_enabled = 0
        call JSCC_Disable()
    else
        let g:js_context_colors_enabled = 1
        call JSCC_Enable()
        call JSCC_Colorize()
    endif
endfunction

"define user commands
"command! -range=% -nargs=0 JSContextColor <line1>,<line2>:call JSCC_Colorize()
"this will no longer work as is
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

if g:js_context_colors_enabled
    call JSCC_Enable()
endif
