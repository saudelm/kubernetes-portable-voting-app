using System;
using System.Data;
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
            var password = Environment.GetEnvironmentVariable("POSTGRES_PASSWORD");
            if (string.IsNullOrWhiteSpace(password))
            {
                Console.Error.WriteLine("POSTGRES_PASSWORD must be supplied externally");
                return 1;
            }
            var connectionString = new NpgsqlConnectionStringBuilder
            {
                Host = GetEnv("POSTGRES_HOST", "db"),
                Port = int.Parse(GetEnv("POSTGRES_PORT", "5432")),
                Username = GetEnv("POSTGRES_USER", "postgres"),
                Password = password,
                Database = GetEnv("POSTGRES_DB", "postgres"),
                Timeout = 3,
                CommandTimeout = 3
            }.ConnectionString;
            var redisOptions = new ConfigurationOptions
            {
                AbortOnConnectFail = false,
                ConnectTimeout = 3000,
                SyncTimeout = 3000
            };
            redisOptions.EndPoints.Add(GetEnv("REDIS_HOST", "redis"), int.Parse(GetEnv("REDIS_PORT", "6379")));
            using var redisConnection = ConnectionMultiplexer.Connect(redisOptions);
            var redis = redisConnection.GetDatabase();
            NpgsqlConnection database = null;
            string pending = null;
            var definition = new { vote = "", voter_id = "" };
            while (true)
            {
                try
                {
                    if (database == null || database.State != ConnectionState.Open)
                    {
                        database?.Dispose();
                        database = new NpgsqlConnection(connectionString);
                        database.Open();
                        using var schema = database.CreateCommand();
                        schema.CommandText = "CREATE TABLE IF NOT EXISTS votes (id VARCHAR(255) NOT NULL UNIQUE, vote VARCHAR(255) NOT NULL)";
                        schema.ExecuteNonQuery();
                        Console.WriteLine("Connected to db");
                    }
                    using (var ping = database.CreateCommand())
                    {
                        ping.CommandText = "SELECT 1";
                        ping.ExecuteNonQuery();
                    }
                    // Keep a popped item until the idempotent upsert succeeds. This does
                    // not guarantee delivery after worker or Redis process failure.
                    pending ??= redis.ListLeftPop("votes");
                    if (pending != null)
                    {
                        var vote = JsonConvert.DeserializeAnonymousType(pending, definition);
                        if (vote == null || string.IsNullOrWhiteSpace(vote.voter_id) ||
                            vote.voter_id.Length > 255 || (vote.vote != "a" && vote.vote != "b"))
                        {
                            Console.Error.WriteLine("Discarding invalid queue item");
                            pending = null;
                            continue;
                        }
                        using var command = database.CreateCommand();
                        command.CommandText = "INSERT INTO votes (id, vote) VALUES (@id, @vote) ON CONFLICT (id) DO UPDATE SET vote = EXCLUDED.vote";
                        command.Parameters.AddWithValue("id", vote.voter_id);
                        command.Parameters.AddWithValue("vote", vote.vote);
                        command.ExecuteNonQuery();
                        pending = null;
                    }
                    Thread.Sleep(100);
                }
                catch (NpgsqlException ex) when (ex.IsTransient || ex.SqlState == "57P01")
                {
                    Console.Error.WriteLine("Database interrupted; reconnecting: " + ex.SqlState);
                    database?.Dispose();
                    database = null;
                    Thread.Sleep(1000);
                }
                catch (TimeoutException)
                {
                    Console.Error.WriteLine("Database timeout; reconnecting");
                    database?.Dispose();
                    database = null;
                    Thread.Sleep(1000);
                }
                catch (RedisException)
                {
                    Console.Error.WriteLine("Redis unavailable; retrying");
                    Thread.Sleep(1000);
                }
                catch (JsonException)
                {
                    Console.Error.WriteLine("Discarding malformed queue item");
                    pending = null;
                }
            }
        }

        private static string GetEnv(string name, string defaultValue)
            => string.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable(name))
                ? defaultValue : Environment.GetEnvironmentVariable(name);
    }
}
