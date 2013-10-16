"plugin to add javascript scope-coloring
"Author: David Wilhelm <dewilhelm@gmail.com>
"
"Note: highlights function scopes in JavaScript
"only supports terminal colors at this time	
"use XtermColorTable plugin to see what colors are available

"this acts as an overlay over the existing highlighting

let s:jscc = expand('<sfile>:p:h').'/../../bin/jscc-cli'

if exists('g:funcjs_colors')
	let s:fun_colors = g:funcjs_colors
else
	let s:fun_colors = [ 252, 10, 11, 172, 1, 161, 63 ]
endif

"define highlight groups dynamically
let c = 0
for colr in s:fun_colors
		exe 'highlight JSCC_Level_' . c . '  ctermfg=' . colr . 'ctermbg=none cterm=none'
		let c += 1
endfor

function! JSCC_Colorize() range
		let colordata_result = system(s:jscc, join(getline(a:firstline, a:lastline), "\n"))
		call clearmatches()
		"colorize the lines based on the color data
		let colordata = eval(colordata_result)
		if type(colordata) == type([])
				for data in colordata
						call matchadd('JSCC_Level_' . data.level, '\%' . data.line . 'l\%>' . (data.from - 1) . 'c.*\%<' . data.thru . 'c' , data.level) 
				endfor
		else
				echo "unexpected output from jslint"
		endif

endfunction

command! -range=% -nargs=0 JSContextColor <line1>,<line2>:call JSCC_Colorize()
