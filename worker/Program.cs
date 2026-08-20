using System;
using System.Data.Common;
using System.Linq;
using System.Net;
using System.Net.Sockets;
using System.Threading;
using Newtonsoft.Json;
using Npgsql;
using StackExchange.Redis;

namespace Worker
{
    public class Program
    {
        public static int Main(string[] args)
        {
            try
            {
                var postgresHost = GetEnv("POSTGRES_HOST", "db");
                var postgresPort = GetEnv("POSTGRES_PORT", "5432");
                var postgresUser = GetEnv("POSTGRES_USER", "postgres");
                var postgresPassword = GetEnv("POSTGRES_PASSWORD", "postgres");
                var postgresDb = GetEnv("POSTGRES_DB", "postgres");
                var redisHost = GetEnv("REDIS_HOST", "redis");
                var redisPort = GetEnv("REDIS_PORT", "6379");
                var postgresConnectionString = $"Host={postgresHost};Port={postgresPort};Username={postgresUser};Password={postgresPassword};Database={postgresDb};";

                var pgsql = OpenDbConnection(postgresConnectionString);
                var redisConn = OpenRedisConnection(redisHost, redisPort);
                var redis = redisConn.GetDatabase();

                var definition = new { vote = "", voter_id = "" };
                while (true)
                {
                    // Slow down to prevent CPU spike, only query each 100ms
                    Thread.Sleep(100);

                    // Reconnect redis if down
                    if (redisConn == null || !redisConn.IsConnected) {
                        Console.WriteLine("Reconnecting Redis");
                        redisConn = OpenRedisConnection(redisHost, redisPort);
                        redis = redisConn.GetDatabase();
                    }
                    string json = redis.ListLeftPopAsync("votes").Result;
                    if (!pgsql.State.Equals(System.Data.ConnectionState.Open))
                    {
                        Console.WriteLine("Reconnecting DB");
                        pgsql.Dispose();
                        pgsql = OpenDbConnection(postgresConnectionString);
                    }

                    if (json != null)
                    {
                        var vote = JsonConvert.DeserializeAnonymousType(json, definition);
                        Console.WriteLine($"Processing vote for '{vote.vote}' by '{vote.voter_id}'");
                        try
                        {
                            UpdateVote(pgsql, vote.voter_id, vote.vote);
                        }
                        catch
                        {
                            // Preserve the item for the restarted worker if the database write fails.
                            redis.ListLeftPush("votes", json);
                            throw;
                        }
                    }
                    else
                    {
                        using var keepAliveCommand = pgsql.CreateCommand();
                        keepAliveCommand.CommandText = "SELECT 1";
                        keepAliveCommand.ExecuteNonQuery();
                    }
                }
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine(ex.ToString());
                return 1;
            }
        }

        private static string GetEnv(string name, string defaultValue)
            => string.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable(name))
                ? defaultValue
                : Environment.GetEnvironmentVariable(name);

        private static NpgsqlConnection OpenDbConnection(string connectionString)
        {
            NpgsqlConnection connection;

            while (true)
            {
                try
                {
                    connection = new NpgsqlConnection(connectionString);
                    connection.Open();
                    break;
                }
                catch (SocketException)
                {
                    Console.Error.WriteLine("Waiting for db");
                    Thread.Sleep(1000);
                }
                catch (DbException)
                {
                    Console.Error.WriteLine("Waiting for db");
                    Thread.Sleep(1000);
                }
            }

            Console.Error.WriteLine("Connected to db");

            var command = connection.CreateCommand();
            command.CommandText = @"CREATE TABLE IF NOT EXISTS votes (
                                        id VARCHAR(255) NOT NULL UNIQUE,
                                        vote VARCHAR(255) NOT NULL
                                    )";
            command.ExecuteNonQuery();

            return connection;
        }

        private static ConnectionMultiplexer OpenRedisConnection(string hostname, string port)
        {
            // Use IP address to workaround https://github.com/StackExchange/StackExchange.Redis/issues/410
            var ipAddress = GetIp(hostname);
            Console.WriteLine($"Found redis at {ipAddress}");

            while (true)
            {
                try
                {
                    Console.Error.WriteLine("Connecting to redis");
                    return ConnectionMultiplexer.Connect($"{ipAddress}:{port}");
                }
                catch (RedisConnectionException)
                {
                    Console.Error.WriteLine("Waiting for redis");
                    Thread.Sleep(1000);
                }
            }
        }

        private static string GetIp(string hostname)
            => Dns.GetHostEntryAsync(hostname)
                .Result
                .AddressList
                .First(a => a.AddressFamily == AddressFamily.InterNetwork)
                .ToString();

        private static void UpdateVote(NpgsqlConnection connection, string voterId, string vote)
        {
            var command = connection.CreateCommand();
            try
            {
                command.CommandText = "INSERT INTO votes (id, vote) VALUES (@id, @vote)";
                command.Parameters.AddWithValue("@id", voterId);
                command.Parameters.AddWithValue("@vote", vote);
                command.ExecuteNonQuery();
            }
            catch (PostgresException ex) when (ex.SqlState == PostgresErrorCodes.UniqueViolation)
            {
                command.CommandText = "UPDATE votes SET vote = @vote WHERE id = @id";
                command.ExecuteNonQuery();
            }
            finally
            {
                command.Dispose();
            }
        }
    }
}
