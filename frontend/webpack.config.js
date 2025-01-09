var path = require('path');

module.exports = {
    entry: './src/main/js/app.js',
    devtool: 'source-map',
    cache: true,
    mode: 'development',
    resolve: {
        alias: {
            'stompjs': __dirname + '/node_modules' + '/stompjs/lib/stomp.js',
        }
    },
    output: {
        path: path.resolve(__dirname, 'build'),  // or #src/main/resources/static/built
        filename: 'bundle.js',
        publicPath: '/', // Ensure all resources are served from the root
    },
    module: {
        rules: [
            {
                test: /\.js$/,
                exclude: /node_modules/,
                use: {
                    loader: 'babel-loader',
                    options: {
                        presets: ["@babel/preset-env", "@babel/preset-react"]
                    }
                }
            }
        ]
    },
    devServer: {
        static: {
            directory: path.resolve(__dirname, 'public'), // Directory containing index.html
        },
        compress: true,
        port: 8081, // Port for webpack-dev-server
        historyApiFallback: true, // Necessary for React Router
        open: true, // Opens browser automatically
        proxy: {
            '/api': 'http://localhost:8080' // Proxy API requests to your Spring Boot backend
        }
    }
};
