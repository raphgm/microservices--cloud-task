import React from 'react';
import ReactDOM from 'react-dom';
import App from './App';  // Import the App component

// Render the App component into a DOM element with id 'root'
ReactDOM.render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
  document.getElementById('root') // Make sure you have an element with this ID in your HTML
);
