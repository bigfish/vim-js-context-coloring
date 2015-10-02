
//options
//TODO: set them from vim global vars
// --jsx : support JSX syntax
// --block-scope : highlight block scope (if es6 is on)
// --block-scope-with-let : highlight block scope only if it contains let variables
// --highlight-function-names : highlight names in function declarations
var jsx = false;
var block_scope = false;
var block_scope_with_let = true;
var highlight_function_names = true;

//parser depends on if jsx support is required
//acorn-jsx should work for es6 
//but escope seems to favor esprima in some cases
if (jsx) {
    var acorn = require('acorn-jsx');
} else {
    var esprima = require('esprima');
}

var escope = require('escope');

function getScopes(input_js) {

    var scopes = [];
    var ast;
    
    if (jsx) {
        ast = acorn.parse(input_js, {
            ecmaVersion: 6,
            ranges: true,
            plugins: { jsx: true }
        });

    } else {
        ast  = esprima.parse(input_js, {
            range: true,
            tolerant:true
        });
    }

    var scopeManager = escope.analyze(ast, {
            optimistic: true,
            ignoreEval: true,
            ecmaVersion: 6,
            sourceType: 'module'
    }); 

    var toplevel = scopeManager.acquire(ast);

    var enclosed = {};
    var declared_globals = [];
    var undeclared_globals = [];

    //define scope for toplevel
    toplevel.variables.forEach(function (variable) {
        declared_globals.push(variable.defs[0].name.name);
        enclosed[variable.defs[0].name.name] = 0;
    });

    toplevel.through.forEach(function (ref) {
        if (ref.identifier.name && !enclosed[ref.identifier.name]) {
            enclosed[ref.identifier.name] = -1;
            undeclared_globals.push(ref.identifier.name);
        }
    });
    scopes.push([0, toplevel.block.range[0], toplevel.block.range[1], enclosed]);

    function hasLet(scope) {
            var v,
            variable,
            vlen = scope.variables.length;

            for (v = 0; v < vlen; v++) {
                    variable = scope.variables[v];
                    if (variable.defs.length &&
                        variable.defs[0].type === "Variable" &&
                                variable.defs[0].parent.kind === 'let') {
                            return true;
                    }

            }
            return false;
    
    }

    function setLevel(scope, level) {

        var enclosed = {};

        scope.level = level;

        //level 0 references already done
        if (level) {

            //add function name to enclosed vars
            if (highlight_function_names &&
                scope.type === 'function' &&
                    scope.block.type === 'FunctionDeclaration') {
                enclosed[scope.block.id.name] = level - 1;
            }

            scope.through.forEach(function (ref) {
                if (ref.resolved) {
                    enclosed[ref.identifier.name] = ref.resolved.scope.level;
                } else {

                    if (declared_globals.indexOf(ref.identifier.name) !== -1) {
                        enclosed[ref.identifier.name] = 0;
                    }  else {
                        //undeclared global level is -1
                        enclosed[ref.identifier.name] = -1;
                    }
                    /*else if (undeclared_globals.indexOf(ref.identifier.name) !== -1) { 
                        enclosed[ref.identifier.name] = -1;
                    }*/
                }
            });           

            scopes.push([level, scope.block.range[0], scope.block.range[1], enclosed]);
        }
            
        //recurse into childScopes
        if (scope.childScopes.length) {
            scope.childScopes.forEach(function (s) {

                //only color function scopes unless use_block_scope is true
                if (block_scope || s.type === "function") {
                    setLevel(s, level + 1);
                } else if (block_scope_with_let && hasLet(s)) {
                    setLevel(s, level + 1);
                } else {
                    setLevel(s, level);
                }
            });
        }

    }

    setLevel(toplevel, 0)

    return scopes;
}

//VIM bindings
function getBufferText(nv) {
    //var start = (new Date()).getTime();
    nv.callFunction('getline', [1, '$'], function (err, res) {
        if (err) debug(err);
        var buftext = res.join("\n");
        var scopes;

        try {
            scopes = getScopes(buftext);
        } catch (e) {
            debug('error occured:' + e);
        }
        
        nv.callFunction('JSCC_Colorize', [JSON.stringify({scopes: scopes})], function (err) {
            if (err) debug(err);
            //var end = (new Date()).getTime();
            //debug('duration: ' + (end - start));
        });
    });

}

plugin.autocmd('BufRead', {
    pattern: '*.js'
}, function (nvim, filename) {
    getBufferText(nvim);
})
plugin.autocmd('TextChanged', {
    pattern: '<buffer>'
}, function (nvim, filename) {
    getBufferText(nvim);
})
plugin.autocmd('InsertLeave', {
    pattern: '<buffer>'
}, function (nvim, filename) {
    getBufferText(nvim);
})

