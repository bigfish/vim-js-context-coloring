"plugin to add javascript scope-coloring
"Version: 0.0.7
"Author: David Wilhelm <dewilhelm@gmail.com>
"
"Note: highlights function scopes in JavaScript
"use XtermColorTable plugin to see what colors are available
let s:jscc = expand('<sfile>:p:h').'/../bin/jscc-cli'

let s:region_count = 1

syntax case match

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

if !exists('g:js_context_colors_highlight_function_names')
    let g:js_context_colors_highlight_function_names = 1
endif

if !exists('g:js_context_colors_show_error_message')
    let g:js_context_colors_show_error_message = 0
endif

if !exists('g:js_context_colors_debug')
    let g:js_context_colors_debug = 0
endif

let s:max_levels = 10

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
    
    
    for lev in range(s:max_levels)
        exe 'syntax region  javaScriptStringD_'. lev .'        start=+"+  skip=+\\\\\|\\$"+  end=+"+ keepend'
        exe "syntax region  javaScriptStringS_". lev ."        start=+'+  skip=+\\\\\|\\$'+  end=+'+ keepend"
        exe 'hi link javaScriptStringS_' . lev . ' JSCC_Level_' . lev
        exe 'hi link javaScriptStringD_' . lev . ' JSCC_Level_' . lev
    endfor

endfunction

"define highlight groups dynamically
function! JSCC_DefineHighlightGroups()

    colors js_context_colors

    let s:jscc_highlight_groups_defined = 1
endfunction


function! JSCC_Colorize()

    let s:region_count = 0

    syntax clear

    let s:scope_level_clusters = {}

    if !g:js_context_colors_colorize_comments
        call JSCC_DefineSyntaxGroups()
    endif

    if !s:jscc_highlight_groups_defined
        call JSCC_DefineHighlightGroups()
    endif

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

    let buftext = join(buflines, "\n")
    "noop if empty string
    if Strip(buftext) == ''
        return
    endif

    "ignore errors from shell command to prevent distracting user
    "syntax errors should be caught by a lint program
    try
        let colordata_result = system(s:jscc, buftext)

        let colordata = eval(colordata_result)

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
                    let var_syntax_group = 'JSCC_Level_' . var_level . '_' . tr(var, '$', 'S')
                    exe "syn match ". var_syntax_group . ' /\<' . var . "\\>\\(\\s*\\:\\)\\@!/ display contained containedin=" . scope_group
                    exe 'hi link ' . var_syntax_group . ' JSCC_Level_' . var_level
                    call add(enclosed_groups, var_syntax_group)
                endif

            endfor

            if g:js_context_colors_highlight_function_names
                "get the function name if it exists
                if len(scope) == 5
                    let fname = scope[4]
                    "function names are always exported into their parent scope
                    let var_level = level - 1
                    let var_syntax_group = 'JSCC_Level_' . var_level . '_' . tr(fname, '$', 'S')
                    exe "syn match ". var_syntax_group . ' /\<' . fname . "\\>\\(\\s*\\:\\)\\@!/ display contained containedin=" . scope_group
                    exe 'hi link ' . var_syntax_group . ' ' . 'JSCC_Level_' . var_level
                    call add(enclosed_groups, var_syntax_group)
                endif
            endif

            let contains = "contains=@jsComment,javaScriptStringS_" . level . ",javaScriptStringD_" . level . ",javaScriptProp,@ScopeLevelCluster_" . (level + 1)

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

        if g:js_context_colors_debug
            echom colordata_result
        endif

    endtry

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
        "Note: currently TextChangedI does not take effect until after InsertMode is
        "exited, thus it is similar to InsertLeave.
        augroup JSContextColorAug
            au!
            au! TextChangedI,TextChanged <buffer> :JSContextColor
        augroup END

    "if < vim 7.4 TextChanged,TextChangedI events are not
    "available and will result in error E216
    catch /^Vim\%((\a\+)\)\=:E216/

            "use different events to trigger update in Vim < 7.4
            augroup JSContextColorAug
                au!
                au! InsertLeave <buffer> :JSContextColor
            augroup END

    endtry

    :JSContextColor

endfunction

function! JSCC_Disable()

    augroup JSContextColorAug
        au!
    augroup END

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
