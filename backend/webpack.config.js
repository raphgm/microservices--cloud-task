module.exports = {
  mode: 'development', // or 'production'
  entry: './src/main/js/index.js',
  output: {
    path: __dirname + '/src/main/resources/static',
    filename: 'bundle.js',
  },
  module: {
    rules: [
      {
        test: /\.js$/,
        exclude: /node_modules/,
        use: {
          loader: 'babel-loader',
          options: {
            presets: ['@babel/preset-react'],
          },
        },
      },
    ],
  },
};
