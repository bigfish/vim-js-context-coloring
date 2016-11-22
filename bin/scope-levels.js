var traverse = require('babel-traverse').default;
var babylon, acorn, esprima, escope;

//OPTIONS
// --jsx : support JSX syntax
// --block-scope : highlight block scope (if es6 is on)
// --block-scope-with-let : highlight block scope only if it contains let variables
// --highlight-function-names : highlight names in function declarations
// --babel: use babel parser

function getScopeLevels(input_js, options) {

  var jsx = options.jsx || false;
  var block_scope = options.block_scope || false;
  var block_scope_with_let = options.block_scope_with_let || false;
  var highlight_function_names = options.highlight_function_names || false;
  var babel = options.babel || false;

  //parser depends on if jsx support is required
  //acorn-jsx should work for es6
  //but escope seems to favor esprima in some cases

  if (babel) {
    babylon = require('babylon');
  } else if (jsx) {
      acorn = require('acorn-jsx');
  } else {
      esprima = require('esprima');
  }

  escope = require('escope');

  var scopes = [];

  var import_re = /^\s*import\s/m;
  var export_re = /^\s*export\s/m;

  function isModule(js) {
    return import_re.test(js) || export_re.test(js);
  }

  var ast;
  var sourceType = isModule(input_js) ? 'module' : 'script';
  var toplevel;

  if (babel) {
    ast = babylon.parse(input_js, {
      allowImportExportEverywhere: true,
      sourceType: sourceType,
      plugins: [
        "jsx",
        "flow",
        "objectRestSpread",
        "doExpressions",
        "decorators",
        "classProperties",
        "exportExtensions",
        "asyncGenerators",
        "functionBind",
        "functionSent",
        "dynamicImport"
      ]
    });

    //TODO: normalize ClassMethod
    traverse(ast, {
      ClassMethod(path) {



      }

    });

  } else if (jsx) {
    ast = acorn.parse(input_js, {
      ecmaVersion: 6,
      ranges: true,
      sourceType: sourceType,
      allowImportExportEverywhere: true,
      allowReturnOutsideFunction: true,
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
    sourceType: sourceType,
  });

  if (babel) {
    toplevel = scopeManager.acquire(ast.program);
  } else {
    toplevel = scopeManager.acquire(ast);
  }

  var enclosed = {};
  var declared_globals = [];
  var undeclared_globals = [];

  //define scope for toplevel
  if (toplevel.variables) {
    toplevel.variables.forEach(function (variable) {
      declared_globals.push(variable.defs[0].name.name);
      enclosed[variable.defs[0].name.name] = 0;
    });
  }

  toplevel.through.forEach(function (ref) {
    if (ref.identifier.name && !enclosed[ref.identifier.name]) {
      enclosed[ref.identifier.name] = -1;
      undeclared_globals.push(ref.identifier.name);
    }
  });

  //location in babel is by offset only
  if (babel) {
    scopes.push([0, toplevel.block.start, toplevel.block.end, enclosed]);
  } else {
    scopes.push([0, toplevel.block.range[0], toplevel.block.range[1], enclosed]);
  }

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
        scope.block.type === 'FunctionDeclaration' &&
        scope.block.id !== null) {
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

      //location in babel is by offset only
      if (babel) {
        scopes.push([level, scope.block.start, scope.block.end, enclosed]);
      } else {
        scopes.push([level, scope.block.range[0], scope.block.range[1], enclosed]);
      }
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

  /*process.stdout.write(JSON.stringify({
    scopes: scopes
  }));*/

}

module.exports = getScopeLevels;

