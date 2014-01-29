"plugin to add javascript scope-coloring
"Version: 0.0.6
"Author: David Wilhelm <dewilhelm@gmail.com>
"
"Note: highlights function scopes in JavaScript
"use XtermColorTable plugin to see what colors are available

let s:jscc = expand('<sfile>:p:h').'/../bin/jscc-cli'

if !exists('g:js_context_colors')
    "using colors suggested by Douglas Crockford
    "1) white: 15
    "2) green: 2
    "3) yellow: 3
    "4) blue: 4
    "5) red: 1
    "6) cyan: 6
    "7) grey: 7
    let g:js_context_colors = [ 15, 2, 3, 4, 1, 6, 7 ]

endif

if !exists('g:js_context_colors_enabled')
    let g:js_context_colors_enabled = 1
endif

if !exists('g:js_context_colors_usemaps')
    let g:js_context_colors_usemaps = 1
endif

if !exists('g:js_context_colors_colorize_comments')
    let g:js_context_colors_colorize_comments = 1
endif

if exists('g:js_context_colors_comment_higroup')
    let s:comment_higroup = g:js_context_colors_comment_higroup
else
    "default Comment colour: gray
    highlight JSCC_CommentHigroup ctermfg=243
    let s:comment_higroup = 'JSCC_CommentHigroup'
endif

if !exists('g:js_context_colors_debug')
    let g:js_context_colors_debug = 0
endif

let s:my_changedtick = b:changedtick

"xterm -- hex RGB colors taken from XTerm Color Table (highly recommended!)
let s:xterm_colors = {
            \ '0':   '#000000', '1':   '#800000', '2':   '#008000', '3':   '#808000', '4':   '#000080',
            \ '5':   '#800080', '6':   '#008080', '7':   '#c0c0c0', '8':   '#808080', '9':   '#ff0000',
            \ '10':  '#00ff00', '11':  '#ffff00', '12':  '#0000ff', '13':  '#ff00ff', '14':  '#00ffff',
            \ '15':  '#ffffff', '16':  '#000000', '17':  '#00005f', '18':  '#000087', '19':  '#0000af',
            \ '20':  '#0000df', '21':  '#0000ff', '22':  '#005f00', '23':  '#005f5f', '24':  '#005f87',
            \ '25':  '#005faf', '26':  '#005fdf', '27':  '#005fff', '28':  '#008700', '29':  '#00875f',
            \ '30':  '#008787', '31':  '#0087af', '32':  '#0087df', '33':  '#0087ff', '34':  '#00af00',
            \ '35':  '#00af5f', '36':  '#00af87', '37':  '#00afaf', '38':  '#00afdf', '39':  '#00afff',
            \ '40':  '#00df00', '41':  '#00df5f', '42':  '#00df87', '43':  '#00dfaf', '44':  '#00dfdf',
            \ '45':  '#00dfff', '46':  '#00ff00', '47':  '#00ff5f', '48':  '#00ff87', '49':  '#00ffaf',
            \ '50':  '#00ffdf', '51':  '#00ffff', '52':  '#5f0000', '53':  '#5f005f', '54':  '#5f0087',
            \ '55':  '#5f00af', '56':  '#5f00df', '57':  '#5f00ff', '58':  '#5f5f00', '59':  '#5f5f5f',
            \ '60':  '#5f5f87', '61':  '#5f5faf', '62':  '#5f5fdf', '63':  '#5f5fff', '64':  '#5f8700',
            \ '65':  '#5f875f', '66':  '#5f8787', '67':  '#5f87af', '68':  '#5f87df', '69':  '#5f87ff',
            \ '70':  '#5faf00', '71':  '#5faf5f', '72':  '#5faf87', '73':  '#5fafaf', '74':  '#5fafdf',
            \ '75':  '#5fafff', '76':  '#5fdf00', '77':  '#5fdf5f', '78':  '#5fdf87', '79':  '#5fdfaf',
            \ '80':  '#5fdfdf', '81':  '#5fdfff', '82':  '#5fff00', '83':  '#5fff5f', '84':  '#5fff87',
            \ '85':  '#5fffaf', '86':  '#5fffdf', '87':  '#5fffff', '88':  '#870000', '89':  '#87005f',
            \ '90':  '#870087', '91':  '#8700af', '92':  '#8700df', '93':  '#8700ff', '94':  '#875f00',
            \ '95':  '#875f5f', '96':  '#875f87', '97':  '#875faf', '98':  '#875fdf', '99':  '#875fff',
            \ '100': '#878700', '101': '#87875f', '102': '#878787', '103': '#8787af', '104': '#8787df',
            \ '105': '#8787ff', '106': '#87af00', '107': '#87af5f', '108': '#87af87', '109': '#87afaf',
            \ '110': '#87afdf', '111': '#87afff', '112': '#87df00', '113': '#87df5f', '114': '#87df87',
            \ '115': '#87dfaf', '116': '#87dfdf', '117': '#87dfff', '118': '#87ff00', '119': '#87ff5f',
            \ '120': '#87ff87', '121': '#87ffaf', '122': '#87ffdf', '123': '#87ffff', '124': '#af0000',
            \ '125': '#af005f', '126': '#af0087', '127': '#af00af', '128': '#af00df', '129': '#af00ff',
            \ '130': '#af5f00', '131': '#af5f5f', '132': '#af5f87', '133': '#af5faf', '134': '#af5fdf',
            \ '135': '#af5fff', '136': '#af8700', '137': '#af875f', '138': '#af8787', '139': '#af87af',
            \ '140': '#af87df', '141': '#af87ff', '142': '#afaf00', '143': '#afaf5f', '144': '#afaf87',
            \ '145': '#afafaf', '146': '#afafdf', '147': '#afafff', '148': '#afdf00', '149': '#afdf5f',
            \ '150': '#afdf87', '151': '#afdfaf', '152': '#afdfdf', '153': '#afdfff', '154': '#afff00',
            \ '155': '#afff5f', '156': '#afff87', '157': '#afffaf', '158': '#afffdf', '159': '#afffff',
            \ '160': '#df0000', '161': '#df005f', '162': '#df0087', '163': '#df00af', '164': '#df00df',
            \ '165': '#df00ff', '166': '#df5f00', '167': '#df5f5f', '168': '#df5f87', '169': '#df5faf',
            \ '170': '#df5fdf', '171': '#df5fff', '172': '#df8700', '173': '#df875f', '174': '#df8787',
            \ '175': '#df87af', '176': '#df87df', '177': '#df87ff', '178': '#dfaf00', '179': '#dfaf5f',
            \ '180': '#dfaf87', '181': '#dfafaf', '182': '#dfafdf', '183': '#dfafff', '184': '#dfdf00',
            \ '185': '#dfdf5f', '186': '#dfdf87', '187': '#dfdfaf', '188': '#dfdfdf', '189': '#dfdfff',
            \ '190': '#dfff00', '191': '#dfff5f', '192': '#dfff87', '193': '#dfffaf', '194': '#dfffdf',
            \ '195': '#dfffff', '196': '#ff0000', '197': '#ff005f', '198': '#ff0087', '199': '#ff00af',
            \ '200': '#ff00df', '201': '#ff00ff', '202': '#ff5f00', '203': '#ff5f5f', '204': '#ff5f87',
            \ '205': '#ff5faf', '206': '#ff5fdf', '207': '#ff5fff', '208': '#ff8700', '209': '#ff875f',
            \ '210': '#ff8787', '211': '#ff87af', '212': '#ff87df', '213': '#ff87ff', '214': '#ffaf00',
            \ '215': '#ffaf5f', '216': '#ffaf87', '217': '#ffafaf', '218': '#ffafdf', '219': '#ffafff',
            \ '220': '#ffdf00', '221': '#ffdf5f', '222': '#ffdf87', '223': '#ffdfaf', '224': '#ffdfdf',
            \ '225': '#ffdfff', '226': '#ffff00', '227': '#ffff5f', '228': '#ffff87', '229': '#ffffaf',
            \ '230': '#ffffdf', '231': '#ffffff', '232': '#080808', '233': '#121212', '234': '#1c1c1c',
            \ '235': '#262626', '236': '#303030', '237': '#3a3a3a', '238': '#444444', '239': '#4e4e4e',
            \ '240': '#585858', '241': '#606060', '242': '#666666', '243': '#767676', '244': '#808080',
            \ '245': '#8a8a8a', '246': '#949494', '247': '#9e9e9e', '248': '#a8a8a8', '249': '#b2b2b2',
            \ '250': '#bcbcbc', '251': '#c6c6c6', '252': '#d0d0d0', '253': '#dadada', '254': '#e4e4e4',
            \ '255': '#eeeeee', 'fg': 'fg', 'bg': 'bg', 'NONE': 'NONE' }

let s:TermColorNames = [  'black',
            \ 'darkblue',
            \ 'darkgreen',
            \ 'darkcyan',
            \ 'darkred',
            \ 'darkmagenta',
            \ 'brown',
            \ 'darkyellow',
            \ 'lightgray',
            \ 'lightgrey',
            \ 'gray',
            \ 'grey',
            \ 'darkgray',
            \ 'darkgrey',
            \ 'blue',
            \ 'lightblue',
            \ 'green',
            \ 'lightgreen',
            \ 'cyan',
            \ 'lightcyan',
            \ 'red',
            \ 'lightred',
            \ 'magenta',
            \ 'lightmagenta',
            \ 'yellow',
            \ 'lightyellow',
            \ 'white' ] 

" Accepts a terminal color number OR a hexadecimal string color OR a color name
" and returns a color Dictionary 
function! JSCC_GetColorDef(c)

    "set defaults
    let colorDef = { 'ctermfg': 'fg', 'ctermbg': 'NONE', 'guifg': 'fg', 'guibg': 'NONE'}
    
    "allow custom color definition dictionaries
    "this allows the possibility of background colors
    if type(a:c) == type({})
        for k in keys(a:c)
            let colorDef[k] = a:c[k]
        endfor
        return colorDef
    endif

    "normalize color as lowercase string
    if type(a:c) != type("string")
        let col = tolower(string(a:c))
    else
        let col = tolower(a:c)
    endif

    "try to find a matching terminal color
    for [term, hex] in items(s:xterm_colors)
        if (col == term || col == hex)
            let colorDef.ctermfg = term
            let colorDef.guifg = hex
            return colorDef
        endif
    endfor

    "if we did not match a term color number it may be a terminal color name
    "these are safe for terminal or gui use
    if index(s:TermColorNames, col) != -1
        let colorDef.ctermfg = col
        let colorDef.guifg = col
        return colorDef
    endif

    "finally, it is possible the color is a GUI color name (only)
    "and so if we are in gui, we try this value for guifg only
    if has("gui_running")
        let colorDef.guifg = col
        return colorDef
    endif

    if g:js_context_colors_debug
        call Warn("Warning!: unsupported color: " . col . ' [JavaScript Context Color]')
    endif

    return colorDef

endfunction

"define highlight groups dynamically
function! JSCC_DefineHighlightGroups()
    let c = 0
    for colr in g:js_context_colors
        let colorDef = JSCC_GetColorDef(colr)
        if type(colorDef) == type({})
            exe 'highlight JSCC_Level_' . c .
                        \ ' ctermfg=' . colorDef.ctermfg .
                        \ ' ctermbg=' . colorDef.ctermbg .
                        \ ' guifg=' . colorDef.guifg .
                        \ ' guibg=' . colorDef.guibg
        endif
        let c += 1
        "avoid type errors
        unlet colr
    endfor
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
    "normalize esprima byte count for Vim (first byte is 1 in Vim)
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

function! HighlightRange(higroup, start, end, priority)
    let group = a:higroup
    let startpos = a:start
    let endpos = a:end
    let priority = a:priority

    if g:js_context_colors_debug
        echom "HighlightRange(" . group . "," . string(startpos) . "," . string(endpos) . "," . priority . ")"
    endif
    "assertions commented out for perf
    "if !IsPos(startpos)
    "call Warn('invalid start pos given to HighlightRange() :' . string(startpos))
    "endif
    "if !IsPos(endpos)
    "call Warn('invalid start pos given to HighlightRange() :' . string(endpos))
    "endif

    "single line regions
    if startpos[0] == endpos[0]
        call matchadd(group, '\%' . startpos[0] . 'l\%>' . (startpos[1] - 1) . 'c.*\%<' . (endpos[1] + 1) . 'c' , priority)

    elseif (startpos[0] + 1) == endpos[0]
        "two line regions
        call matchadd(group, '\%' . startpos[0] . 'l\%>' . (startpos[1] - 1) . 'c.*', priority)
        call matchadd(group, '\%' . endpos[0] . 'l.*\%<' . (endpos[1] + 1) . 'c' , priority)
    else
        "multiline regions
        call matchadd(group, '\%' . startpos[0] . 'l\%>' . (startpos[1] - 1) . 'c.*', priority)
        call matchadd(group, '\%>' . startpos[0] . 'l.*\%<' . endpos[0] . 'l', priority)
        call matchadd(group, '\%' . endpos[0] . 'l.*\%<' . (endpos[1] + 1) . 'c' , priority)
    endif

endfunction

function! HighlightComments()

    "highlight comments according to comment higroup, not function scope
    "unless g:js_context_colors_colorize_comments is set to 1
    "NOTE: this currently is buggy as comments inside strings
    "can cause broken coloring.. TODO: a better solution would be
    "to use keep Vim syntax highlighting for comments
    "but the priority of syntax highlighting is lower
    "than the matchadd() function used to mark scopes
    "furthermore, re-highlighting comments is slowing down
    "highlighting. Thus this functionality is deprecated
    "and may be removed in future unless a better solution
    "is found

    if g:js_context_colors_colorize_comments
        return
    endif

    call matchadd(s:comment_higroup, '\/\/.*', 50)

    "block comments
    call cursor(1,1)
    "problem: this will also highlight comments inside strings!
    while search('\/\*', 'cW') != 0

        let startbc_pos = getpos('.')
        let startbc = [startbc_pos[1], startbc_pos[2]]

        "echom 'found block comment at ' . startbc[0] . ',' . startbc[1]

        if search('\*\/', 'cWe')

            let endbc_pos = getpos('.')
            let endbc = [endbc_pos[1], endbc_pos[2]]

            "echom 'ends at ' . endbc[1]
            call cursor(endbc[0], endbc[1])

            call HighlightRange(s:comment_higroup, startbc, endbc, 50)
        endif

    endwhile

endfunction

function! JSCC_Colorize()

    call clearmatches()

    let save_cursor = getpos(".")

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
        "colorize the lines based on the color data
        let colordata = eval(colordata_result)
        if type(colordata) == type([])
            "initially highlight all text as global
            "as eslevels does not seem to provide highlight data
            "for starting and end regions
            call insert(colordata, [0, 0, len(buftext)])
            "highlight all regions provided by eslevels

            for data in colordata
                let level = data[0]
                "normalize implied globals (-1)
                "TODO: they could be highlighted differently?
                if level == -1
                    let level = 0
                endif
                "get line number from offset
                let start_pos = GetPosFromOffset(data[1])
                let end_pos = GetPosFromOffset(data[2])

                call HighlightRange('JSCC_Level_' . level, start_pos, end_pos, level)
            endfor

            call HighlightComments()
        endif

    catch
        echom "JSContextColors Error. Enable debug mode for details."

        if g:js_context_colors_debug
            echom colordata_result
        endif
    endtry

    call setpos('.', save_cursor)
endfunction

function! JSCC_UpdateOnChange()
    if s:my_changedtick != b:changedtick
        let s:my_changedtick = b:changedtick
        call JSCC_Colorize()
    endif
endfunction

function! JSCC_Enable()
    "if < vim 7.4 TextChanged,TextChangedI events are not
    "available and will result in error E216
    try

        augroup JSContextColorAug
            au!
            au! TextChangedI,TextChanged <buffer> :JSContextColor
        augroup END

    catch /^Vim\%((\a\+)\)\=:E216/

        "use different events to trigger update in Vim < 7.4
        augroup JSContextColorAug
            au!
            au! InsertLeave <buffer> :JSContextColor
            au! CursorMoved <buffer> call JSCC_UpdateOnChange()
        augroup END

    endtry

    :JSContextColor

endfunction

function! JSCC_Disable()
    call clearmatches()
    augroup JSContextColorAug
        au!
    augroup END
    "echo 'JSContextColor disabled'
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

"define highlight group and do colorizing once for buffer
if g:js_context_colors_enabled
    call JSCC_Enable()
    :JSContextColor
endif


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

