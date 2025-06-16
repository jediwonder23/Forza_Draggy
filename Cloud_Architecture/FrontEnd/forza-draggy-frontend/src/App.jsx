import { useState } from 'react';
import './App.css';
import { S3Client, PutObjectCommand } from '@aws-sdk/client-s3';
import awsConfig from './awsConfig';

function App() {
  const [selectedFile, setSelectedFile] = useState(null);
  const [uploading, setUploading] = useState(false);
  const [message, setMessage] = useState('');

  const handleFileChange = (event) => {
    const file = event.target.files[0];
    if (!file) return;
    
    // Optional: validate file type or size here
    setSelectedFile(file);
    setMessage('');
  };

  const handleUpload = async () => {
    if (!selectedFile) {
      setMessage('Please select a file to upload.');
      return;
    }

    const s3 = new S3Client(awsConfig);
    const params = {
      Bucket: awsConfig.bucketName,
      Key: selectedFile.name,
      Body: selectedFile,
      ContentType: selectedFile.type,
    };

    try {
      setUploading(true);
      setMessage('Uploading...');

      const command = new PutObjectCommand(params);
      await s3.send(command);

      setMessage('✅ File uploaded successfully!');
      setSelectedFile(null);
    } catch (err) {
      console.error('Upload error:', err);
      setMessage('❌ Upload failed.');
    } finally {
      setUploading(false);
    }
  };

  return (
    <div className="App">
      <h1>Forza Draggy</h1>
      <input type="file" onChange={handleFileChange} />
      <button onClick={handleUpload} disabled={!selectedFile || uploading}>
        {uploading ? 'Uploading...' : 'Upload'}
      </button>
      {message && <p>{message}</p>}
    </div>
  );
}

export default App;
