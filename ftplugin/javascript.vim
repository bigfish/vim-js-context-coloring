"plugin to add javascript scope-coloring
"Version: 0.0.7
"Author: David Wilhelm <dewilhelm@gmail.com>
"
"Note: highlights function scopes in JavaScript
"use XtermColorTable plugin to see what colors are available
let s:jscc = expand('<sfile>:p:h').'/../bin/jscc-cli'

let s:region_count = 1

let s:orig_foldmethod=&foldmethod

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


function! HighlightRange(higroup, start, end, level)
    let group = a:higroup
    let startpos = a:start
    let endpos = a:end

    let s:region_count = s:region_count + 1
    let group_name = group  . s:region_count
    let cmd = "syn region ". group_name  . " start='\\%" . startpos[0] ."l\\%". startpos[1] ."c' end='\\%" . endpos[0] . "l\\%" . endpos[1] . "c' contains=ALL fold"
    "echom cmd
    exe cmd
    exe 'hi link ' . group_name . ' ' . 'JSCC_Level_' . a:level

    return group_name

endfunction

let s:jscc_highlight_groups_defined = 0

function! JSCC_DefineCommentSyntaxGroups()

    "define JavaScript comments syntax -- all syntax is cleared when
    "colorizing is done, so they must be redefined
    syntax keyword javaScriptCommentTodo    TODO FIXME XXX TBD contained
    syntax region  javaScriptLineComment    start=+\/\/+ end=+$+ keepend contains=javaScriptCommentTodo
    syntax region  javaScriptLineComment    start=+^\s*\/\/+ skip=+\n\s*\/\/+ end=+$+ keepend contains=javaScriptCommentTodo fold
    syntax region  javaScriptComment        start="/\*"  end="\*/" contains=javaScriptCommentTodo fold

endfunction

"define highlight groups dynamically
function! JSCC_DefineHighlightGroups()

    colors js_context_colors

    let s:jscc_highlight_groups_defined = 1
endfunction


function! JSCC_Colorize()

    let s:region_count = 0

    syntax clear

    if !g:js_context_colors_colorize_comments
        call JSCC_DefineCommentSyntaxGroups()
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

            let scope_group =  HighlightRange(group_name, start_pos, end_pos, level)

            let enclosed = scope[3]

            for var in keys(enclosed)
                let var_level = enclosed[var]
                "ignore vars which are contained in deeper scopes
                "-- they will be defined with those scopes
                if var_level < level
                    let cmd = "syn keyword ". 'JSCC_Level_' . var_level . ' ' . var . " display contained containedin=" . scope_group
                    exe cmd
                endif
            endfor
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

    exe "setlocal foldmethod " . s:orig_foldmethod

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
