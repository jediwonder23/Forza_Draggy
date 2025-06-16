import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App.jsx';

import { Amplify } from 'aws-amplify';
import { awsConfig } from './awsConfig.js';
Amplify.configure(awsConfig);

import './index.css';
ReactDOM.createRoot(document.getElementById('root')).render(<App />);

