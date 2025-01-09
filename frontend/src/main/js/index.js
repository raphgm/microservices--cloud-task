// frontend/src/main/js/index.js
import React from 'react';
import ReactDOM from 'react-dom';
import App from './App';  // Assuming you have an App.js file

ReactDOM.render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
  document.getElementById('root')  // Make sure there's a div with id 'root' in your index.html
);
