import { useState } from 'react';
import { apiEndpoint } from '../awsConfig.js';

export default function RunForm({ token, onSaved }) {
  const [speed, setSpeed] = useState('');
  const [acc, setAcc] = useState('');
  const [timestamp, setTs] = useState('');

  const submit = async () => {
    const res = await fetch(`${apiEndpoint}/run`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${token}`,
      },
      body: JSON.stringify({
        user: 'self',
        timestamp,
        metrics: { speed: Number(speed), acceleration: Number(acc) },
      }),
    });
    if (res.ok) {
      onSaved();
      setSpeed('');
      setAcc('');
      setTs('');
    } else {
      alert('Submit error');
    }
  };

  return (
    <div className="card">
      <h2>Log New Run</h2>
      <input value={timestamp} onChange={e => setTs(e.target.value)} placeholder="Timestamp ISO" />
      <input value={speed} onChange={e => setSpeed(e.target.value)} placeholder="Speed" type="number" />
      <input value={acc} onChange={e => setAcc(e.target.value)} placeholder="Acceleration" type="number" />
      <button onClick={submit}>Save</button>
    </div>
  );
}
