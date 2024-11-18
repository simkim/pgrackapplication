require "pg"
# use Rack::Reloader, 0
use Rack::ContentLength

conn = PG.connect(dbname: "test")

conn.exec(File.read("application.sql"))

app = proc do |env|
  status, body = conn
    .exec("select * from route($1, $2)", [env["REQUEST_METHOD"], env["REQUEST_PATH"]])
    .first
    .values_at("status", "body")

  [status.to_i, {"content-type" => "text/html"}, [body]]
end

run app
