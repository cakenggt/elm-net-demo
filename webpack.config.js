var path = require('path');

module.exports = {
  entry: {
    index: [
      './src/index.js'
    ]
  },

  output: {
    path: path.resolve(__dirname + '/dist'),
    filename: '[name].js',
  },

  module: {
    rules: [
      {
        test:    /\.elm$/,
        exclude: [/elm-stuff/, /node_modules/],
        loader:  'elm-webpack-loader?verbose=true&warn=true',
      },
      {
        test:    /\.html$/,
        exclude: /node_modules/,
        loader:  'file-loader?name=[name].[ext]',
      },
      {
        test: /\.(css|scss)$/,
        use: [
          'style-loader',
          'css-loader',
        ]
      }
    ],

    noParse: /\.elm$/,
  },

  devServer: {
    inline: true,
    stats: { colors: true },
  },


};
