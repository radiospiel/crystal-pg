require "./pg/*"

module PG
  alias PGValue = String | Nil | Bool | Int32 | Float32 | Float64 | Time | JSON::Type

  def self.connect(conninfo)
    conn = Connection.new(conninfo)
    conn.exec("SET extra_float_digits = 3")
    conn
  end
end
