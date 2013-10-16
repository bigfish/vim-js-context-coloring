#!/usr/bin/env node

/*jshint node:true, strict:false*/
var JSLINT = require("./jslint.js"),
    options = {
        evil:true,
        passfail:false
    },
    input_js,
    lint,
    data,
    color_data;

//feed std in to jslint, with options
stdin = process.openStdin();
stdin.setEncoding('utf8');

stdin.on('data', function (chunk) {
    input_js += chunk;
});

stdin.on('end', function () {
    lint = JSLINT(input_js);
    data = JSLINT.data();
    color_data = JSLINT.color(data);
    //console.dir(color_data);
    process.stdout.write(JSON.stringify(color_data));
});
