
var Promise = require('promise');

//options
//TODO: set them from vim global vars
// --jsx : support JSX syntax
// --block-scope : highlight block scope (if es6 is on)
// --block-scope-with-let : highlight block scope only if it contains let variables
// --highlight-function-names : highlight names in function declarations

var options = {
    jsx: false,
    block_scope: false,
    block_scope_with_let: true,
    highlight_function_names: true,
    es5: false,
    enabled: true,
    debug: false
};

var option_names = Object.keys(options);

var acorn;
var esprima;
var getVar;

function _debug() {
    if (options.debug) {
        debug.apply(null, arguments);
    }
}

function setConfig(nv) {

    //promise-ified version of nvim.getVar()
    getVar = function (varname) {
        return new Promise(function (resolve, reject) {
            //check var exists 
            nv.callFunction('exists', [varname], function (err, res) {
                if (res) {
                    nv.getVar(varname, function (err, res) {
                        if (err) {
                            reject(err);
                        } else {
                            resolve(res);
                        } 
                    });
                } else {
                    _debug('var:' + varname + ' not found -- setting to default');
                    resolve(null);
                }
            })
        });
    } 

    //get options values
    Promise.all(option_names.map(function (key) {
        return getVar('js_context_colors_' + key);
    })).then(function (res) {

        res.forEach(function (val, idx) {
            if (val !== null) {
                options[option_names[idx]] = val;
            }
        });

        //parser depends on if jsx support is required
        //acorn-jsx should work for es6 
        //but escope seems to favor esprima in some cases
        if (options.jsx) {
            acorn = require('acorn-jsx');
        } else {
            esprima = require('esprima');
        }

        if (options.enabled) {
            addAutoCommands();
        }

    }).catch(function (err) {
        _debug('error reading config vars', err);
    });
}

var escope = require('escope');

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

function getScopes(input_js) {

    var scopes = [];
    var ast;
    
    if (options.jsx) {
        ast = acorn.parse(input_js, {
            ecmaVersion: 6,
            ranges: true,
            allowHashBang: true,
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
            //tolerate export
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

    function setLevel(scope, level) {

        var enclosed = {};

        scope.level = level;

        //level 0 references already done
        if (level) {

            //add function name to enclosed vars
            if (options.highlight_function_names &&
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
                if (options.block_scope || s.type === "function") {
                    setLevel(s, level + 1);
                } else if (options.block_scope_with_let && hasLet(s)) {
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
        if (err) _debug(err);
        var buftext = res.join("\n");
        var scopes;

        try {
            scopes = getScopes(buftext);
        } catch (e) {
            _debug('error occured:' + e);
        }
        
        nv.callFunction('JSCC_Colorize2', [JSON.stringify({scopes: scopes})], function (err) {
            if (err) _debug(err);
            //var end = (new Date()).getTime();
            //debug('duration: ' + (end - start));
        });
    });

}

plugin.autocmd('BufRead', {
    pattern: '*.js'
}, setConfig);

plugin.autocmd('User', {
    pattern: 'jscc.enable'
}, function (nvim) {
    options.enabled = true;
    //colorize
    getBufferText(nvim);
});

plugin.autocmd('User', {
    pattern: 'jscc.disable'
}, function (nvim) {
    options.enabled = false;
});

function addAutoCommands(argument) {
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
}
