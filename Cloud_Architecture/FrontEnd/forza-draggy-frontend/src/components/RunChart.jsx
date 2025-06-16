import { Line } from 'react-chartjs-2';
import { Chart as ChartJS, LineElement, PointElement, CategoryScale, LinearScale, Tooltip, Legend } from 'chart.js';
ChartJS.register(LineElement, PointElement, CategoryScale, LinearScale, Tooltip, Legend);

export default function RunChart({ runs = [] }) {
  const data = {
    labels: runs.map(r => r.timestamp),
    datasets: [
      {
        label: 'Speed',
        data: runs.map(r => r.metrics?.speed),
      },
      {
        label: 'Acceleration',
        data: runs.map(r => r.metrics?.acceleration),
      },
    ],
  };
  return (
    <div className="card">
      <h2>Performance Chart</h2>
      <Line data={data} />
    </div>
  );
}
