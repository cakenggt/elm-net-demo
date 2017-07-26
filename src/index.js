'use strict';

require('./index.html');
require('./styles.css');
var Elm = require('./Main.elm');

Elm.Main.embed(document.getElementById('main'));
