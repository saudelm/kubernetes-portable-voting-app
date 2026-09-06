var express = require('express'),
    path = require('path'),
    { Pool } = require('pg'),
    app = express(),
    server = require('http').Server(app),
    io = require('socket.io')(server);

var port = process.env.PORT || 4000;
var postgresHost = process.env.POSTGRES_HOST || 'db';
var postgresPort = parseInt(process.env.POSTGRES_PORT || '5432');
var postgresUser = process.env.POSTGRES_USER || 'postgres';
var postgresPassword = process.env.POSTGRES_PASSWORD;
if (!postgresPassword) throw new Error('POSTGRES_PASSWORD must be supplied externally');
var postgresDatabase = process.env.POSTGRES_DB || 'postgres';

io.on('connection', function (socket) {

  socket.emit('message', { text : 'Welcome!' });

  socket.on('subscribe', function (data) {
    socket.join(data.channel);
  });
});

var pool = new Pool({
  host: postgresHost,
  port: postgresPort,
  user: postgresUser,
  password: postgresPassword,
  database: postgresDatabase,
  connectionTimeoutMillis: 3000,
  query_timeout: 3000,
  max: 4
});

var poller = require('./vote-poller').createVotePoller(
  pool,
  function (votes) { io.sockets.emit('scores', JSON.stringify(votes)); }
);
poller.start();

app.use(express.urlencoded());
app.use(express.static(__dirname + '/views'));

app.get('/', function (req, res) {
  res.sendFile(path.resolve(__dirname + '/views/index.html'));
});

app.get('/healthz', function (req, res) {
  res.status(200).send('ok');
});

app.get('/readyz', async function (req, res) {
  if (poller.ready()) {
    res.status(200).send('ready');
  } else {
    res.status(503).send('database unavailable');
  }
});

server.listen(port, function () {
  var port = server.address().port;
  console.log('App running on port ' + port);
});

process.on('SIGTERM', async function () {
  await poller.stop();
  io.close();
  server.close();
  await pool.end();
});
