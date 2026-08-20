const socket = io();
const bg1 = document.getElementById('background-stats-1');
const bg2 = document.getElementById('background-stats-2');
const aPercent = document.getElementById('a-percent');
const bPercent = document.getElementById('b-percent');
const total = document.getElementById('total');

document.body.style.opacity = 1;

socket.on('scores', function (json) {
  const data = JSON.parse(json);
  const a = Number.parseInt(data.a || 0, 10);
  const b = Number.parseInt(data.b || 0, 10);
  const percentages = getPercentages(a, b);
  const voteCount = a + b;

  bg1.style.width = `${percentages.a}%`;
  bg2.style.width = `${percentages.b}%`;
  aPercent.textContent = `${percentages.a.toFixed(1)}%`;
  bPercent.textContent = `${percentages.b.toFixed(1)}%`;
  total.textContent = voteCount === 0
    ? 'No votes yet'
    : `${voteCount} ${voteCount === 1 ? 'vote' : 'votes'}`;
});

function getPercentages(a, b) {
  if (a + b > 0) {
    const aPercentValue = Math.round(a / (a + b) * 100);
    return { a: aPercentValue, b: 100 - aPercentValue };
  }
  return { a: 50, b: 50 };
}
