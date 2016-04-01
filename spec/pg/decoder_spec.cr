require "../spec_helper"

private def test_decode(result_format, name, select, expected, file = __FILE__, line = __LINE__)
  it "#{result_format}/#{name}", file, line do
    DB.result_format = result_format
    rows = DB.exec("select #{select}").rows
    rows.size.should eq(1), file, line
    rows.first.size.should eq(1), file, line
    rows.first.first.should eq(expected), file, line
  end
end

describe PG::Decoder do
  [ :binary, :text ].each do |result_format|
    #           name,             sql,              result
    test_decode result_format, "undefined    ", "'what'       ", "what"
    test_decode result_format, "text         ", "'what'::text ", "what"
    test_decode result_format, "empty strings", "''           ", ""
    test_decode result_format, "null as nil  ", "null         ", nil
    test_decode result_format, "boolean false", "false        ", false
    test_decode result_format, "boolean true ", "true         ", true
    test_decode result_format, "int2 smallint", "1::int2      ", 1
    test_decode result_format, "int4 int     ", "1::int4      ", 1
    test_decode result_format, "int8 bigint  ", "1::int8      ", 1
    test_decode result_format, "float        ", "-0.123::float", -0.123

    test_decode result_format, "double prec.", "'35.03554004971999'::float8", 35.03554004971999
    test_decode result_format, "float prec.", "'0.10000122'::float4", 0.10000122_f32

    test_decode result_format, "uuid", "'7d61d548124c4b38bc05cfbb88cfd1d1'::uuid", "7d61d548-124c-4b38-bc05-cfbb88cfd1d1"
    test_decode result_format, "uuid", "'7d61d548-124c-4b38-bc05-cfbb88cfd1d1'::uuid", "7d61d548-124c-4b38-bc05-cfbb88cfd1d1"

    test_decode result_format, "xml", "'<foo>bar</foo>'::xml", "<foo>bar</foo>"

    if Helper.db_version_gte(9, 2)
      test_decode result_format, "json", %('[1,"a",true]'::json), JSON.parse(%([1,"a",true]))
      test_decode result_format, "json", %('{"a":1}'::json), JSON.parse(%({"a":1}))
    end
    if Helper.db_version_gte(9, 4)
      test_decode result_format, "jsonb", "'[1,2,3]'::jsonb", JSON.parse("[1,2,3]")
    end

    test_decode result_format, "timestamptz", "'2015-02-03 16:15:13-01'::timestamptz",
      Time.new(2015, 2, 3, 17, 15, 13, 0, Time::Kind::Utc)

    test_decode result_format, "timestamptz", "'2015-02-03 16:15:14.23-01'::timestamptz",
      Time.new(2015, 2, 3, 17, 15, 14, 230, Time::Kind::Utc)

    test_decode result_format, "timestamp", "'2015-02-03 16:15:15'::timestamp",
      Time.new(2015, 2, 3, 16, 15, 15, 0, Time::Kind::Utc)

    test_decode result_format, "date", "'2015-02-03'::date",
      Time.new(2015, 2, 3, 0, 0, 0, 0, Time::Kind::Utc)
  end

  # Different in binary and text modi: bytea returns a UInt8[] in text format, and a 
  # Slice in :binary format.
  test_decode :text, "bytea", "E'\\\\001\\\\134\\\\176'::bytea", UInt8[0o001, 0o134, 0o176]
  test_decode :text, "bytea", "E'\\\\005\\\\000\\\\377\\\\200'::bytea", UInt8[5, 0, 255, 128]
  test_decode :text, "bytea empty", "E''::bytea", UInt8[]

  test_decode :binary, "bytea", "E'\\\\001\\\\134\\\\176'::bytea", Slice(UInt8).new UInt8[0o001, 0o134, 0o176].to_unsafe, 3
  test_decode :binary, "bytea", "E'\\\\005\\\\000\\\\377\\\\200'::bytea", Slice(UInt8).new UInt8[5, 0, 255, 128].to_unsafe, 4
  test_decode :binary, "bytea empty", "E''::bytea", Slice(UInt8).new UInt8[].to_unsafe, 0

  # Only working in text mode
  test_decode :text, "money", "'$1,234.56'::money", 1234.56
  test_decode :text, "float unspec.", "0.10000122", 0.10000122_f64
  test_decode :text, "cidr", "'192.168.1'::cidr", "192.168.1.0/24"
  test_decode :text, "inet", "'192.168.1.1'::inet", "192.168.1.1"
  test_decode :text, "macaddr", "'08:00:2b:01:02:03'::macaddr", "08:00:2b:01:02:03"
end
