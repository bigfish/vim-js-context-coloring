"plugin to add javascript scope-coloring
"Version: 0.0.5
"Author: David Wilhelm <dewilhelm@gmail.com>
"
"Note: highlights function scopes in JavaScript
"only supports terminal colors at this time
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
	let g:js_context_colors_colorize_comments = 0
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

"define highlight groups dynamically
function! JSCC_DefineHighlightGroups()
	let c = 0
	for colr in g:js_context_colors
		exe 'highlight JSCC_Level_' . c . '  ctermfg=' . colr . ' ctermbg=NONE cterm=NONE'
		let c += 1
	endfor

endfunction

"parse functions
function! Strip(input_string)
    return substitute(a:input_string, '^\s*\(.\{-}\)\s*$', '\1', '')
endfunction

"following functions are used for debugging
function! Warn(msg)
		echohl Error | echom msg
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

	"colorizing is the default behaviour in eslevels but not in this plugin
	"it restores the default comment syntax highlighting
	"unless g:js_context_colors_colorize_comments is set to 1

	if exists('g:js_context_colors_colorize_comments') && g:js_context_colors_colorize_comments
			return
	endif

	call matchadd(s:comment_higroup, '\/\/.*', 50)

	"block comments
	call cursor(1,1)

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

