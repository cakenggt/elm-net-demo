# elm-net-demo

Demo of the elm-net library. Backpropagation algorithm for the elm-net library
was gotten from https://mattmazur.com/2015/03/17/a-step-by-step-backpropagation-example/

Can be viewed here: https://cakenggt.github.io/elm-net-demo/dist/

Pre-populated training sets can be given by encoding the input and target sets and adding them as params

```
var inputs = [["0","0"],["1","0"],["0","1"],["1","1"]];
var targets = [["0"],["1"],["1"],["0"]];
var link = "https://cakenggt.github.io/elm-net-demo/dist?"+"inputs="+encodeURI(JSON.stringify(inputs))+"&targets="+encodeURI(JSON.stringify(targets));
```

To produce https://cakenggt.github.io/elm-net-demo/dist?inputs=%5B%5B%220%22,%220%22%5D,%5B%221%22,%220%22%5D,%5B%220%22,%221%22%5D,%5B%221%22,%221%22%5D%5D&targets=%5B%5B%220%22%5D,%5B%221%22%5D,%5B%221%22%5D,%5B%220%22%5D%5D
