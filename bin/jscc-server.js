
var PORT = 6969;
var net = require('net');
var getScopeLevels = require('./scope-levels.js');
var options = {
  babel: false,
  jsx: false,
  block_scope: false,
  block_scope_with_let: false,
  highlight_function_names: false
};
//handle //CLI args (just flags, no values)
// --jsx : support JSX syntax
// --block-scope : highlight block scope (if es6 is on)
// --block-scope-with-let : highlight block scope only if it contains let variables
// --highlight-function-names : highlight names in function declarations
// --babel: use babel parser

if (process.argv.length > 2) {
    if (process.argv.indexOf("--jsx") !== -1) {
        options.jsx = true;
    }
    if (process.argv.indexOf("--block-scope") !== -1) {
        options.block_scope = true;
    }
    if (process.argv.indexOf("--block-scope-with-let") !== -1) {
        options.block_scope_with_let = true;
    }
    if (process.argv.indexOf("--highlight-function-names") !== -1) {
        options.highlight_function_names = true;
    }
    if (process.argv.indexOf("--babel") !== -1) {
        options.babel = true;
    }
}

var server = net.createServer(function (socket) {

  socket.setEncoding('utf8');

  var input = "";
  var scopes;

  socket.on('data', (chunk) => {
    input += chunk;

    //if we got newline the text is finished
    if (chunk.indexOf('\n') !== -1) {

      try {
        scopes = getScopeLevels(input, options);
        socket.write(JSON.stringify({scopes: scopes}) + '\r\n');
      } catch(err) {
        console.log(err);
      }
      input = "";

    }

    //socket.write( 'got data' + '\r\n');
  });

  socket.on('end', () => {
    //process input and get levels JSON
    //return result
    //reset input
    //socket.write('got end of data \r\n');

    var input = "";
  });

  socket.on('error', (err) => {
    //socket.write('error' . err);
    console.log(err);
  });

  //socket.pipe(socket);

});

server.on('error', (err) => {
  throw err;
});

server.listen(PORT, () => {
  console.log('server bound to port:', PORT);
});
