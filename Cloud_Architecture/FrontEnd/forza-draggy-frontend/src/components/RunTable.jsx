export default function RunTable({ runs = [] }) {
  return (
    <div className="card">
      <h2>Run History</h2>
      <table>
        <thead>
          <tr><th>Timestamp</th><th>Speed</th><th>Acceleration</th></tr>
        </thead>
        <tbody>
          {runs.map(r => (
            <tr key={r.run_id}>
              <td>{r.timestamp}</td>
              <td>{r.metrics?.speed}</td>
              <td>{r.metrics?.acceleration}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
