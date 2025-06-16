import { useState, useEffect } from 'react';
import AuthForm from './components/AuthForm.jsx';
import RunForm from './components/RunForm.jsx';
import RunTable from './components/RunTable.jsx';
import RunChart from './components/RunChart.jsx';
import { apiEndpoint } from './awsConfig.js';

export default function App() {
  const [token, setToken] = useState(null);
  const [runs, setRuns] = useState([]);

  const fetchRuns = async (jwt) => {
    const res = await fetch(`${apiEndpoint}/runs`, {
      headers: { Authorization: `Bearer ${jwt}` },
    });
    if (res.ok) {
      setRuns(await res.json());
    }
  };

  // refresh table after login or new save
  useEffect(() => { if (token) fetchRuns(token); }, [token]);

  if (!token) return <AuthForm onAuth={setToken} />;

  return (
    <div className="container">
      <RunForm token={token} onSaved={() => fetchRuns(token)} />
      <RunTable runs={runs} />
      <RunChart runs={runs} />
    </div>
  );
}
