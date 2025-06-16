import { useState } from 'react';
import { Auth } from 'aws-amplify';

export default function AuthForm({ onAuth }) {
  const [email, setEmail] = useState('');
  const [pw, setPw] = useState('');
  const [error, setError] = useState('');

  const signIn = async () => {
    try {
      const res = await Auth.signIn(email, pw);
      const { idToken } = res.signInUserSession;
      onAuth(idToken.jwtToken);
    } catch (e) {
      setError(e.message);
    }
  };

  const signUp = async () => {
    try {
      await Auth.signUp({ username: email, password: pw, attributes: { email } });
      alert('User created – ask admin to confirm or confirm via email.');
    } catch (e) {
      setError(e.message);
    }
  };

  return (
    <div className="card">
      <h2>Login / Sign‑Up</h2>
      <input placeholder="Email" value={email} onChange={e => setEmail(e.target.value)} />
      <input placeholder="Password" value={pw} type="password" onChange={e => setPw(e.target.value)} />
      <button onClick={signIn}>Sign In</button>
      <button onClick={signUp}>Sign Up</button>
      {error && <p className="error">{error}</p>}
    </div>
  );
}
