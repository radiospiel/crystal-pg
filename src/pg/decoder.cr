require "json"

$warned = Hash(String, Bool).new(false)
def warn_once(s)
  unless $warned[s]
    $warned[s] = true
    STDERR.puts(s)
  end
end

module PG
  alias PGValue = String | Nil | Bool | Int32 | Float32 | Float64 | Time | JSON::Type

  module Decoder
    abstract class Decoder
      def decode_string(s)
        s
      end

      def decode(bytes)
        decode_string String.new(bytes)
      end
    end

    class DefaultDecoder < Decoder
      def decode_string(s)
        s
      end
    end

    class BoolDecoder < Decoder
      def decode_string(s)
        s == "t"
      end
    end

    class Int2Decoder < Decoder
      def decode_string(s)
        s.to_i
      end
    end

    class IntDecoder < Decoder
      def decode_string(s)
        s.to_i
      end
    end

    class Int8Decoder < Decoder
      def decode_string(s)
        s.to_i
      end
    end

    class MoneyDecoder < Decoder
      # byte swapped in the same way as int4
      def decode_string(s)
        warn_once "converting a money value with an arbitrary resolution into a float, potentially losing accuracy"
        s = s.gsub(/[$,]/, "")
        s.to_f64
      end
    end

    class Float32Decoder < Decoder
      # byte swapped in the same way as int4
      def decode_string(s)
        s.to_f32
      end
    end

    class Float64Decoder < Decoder
      def decode_string(s)
        s.to_f
      end
    end

    class NumericDecoder < Decoder
      def decode_string(s)
        warn_once "converting a numeric value with an arbitrary resolution into a float, potentially losing accuracy"
        s.to_f
      end
    end

    class JsonDecoder < Decoder
      def decode_string(s)
        JSON.parse(s)
      end
    end

    class JsonbDecoder < Decoder
      def decode_string(s)
        JSON.parse(s)
      end
    end

    class DateDecoder < Decoder
      def decode_string(s)
        unless s =~ /^(\d+)-(\d+)-(\d+)$/
          raise ArgumentError.new("Cannot parse date string: #{s.inspect}")
        end

        year, mon, day = $1, $2, $3
        Time.new(year.to_i, mon.to_i, day.to_i, 0, 0, 0, 0, Time::Kind::Utc)
      end
    end

    class TimeDecoder < Decoder
      def decode_string(s)
        unless s =~ /^(\d+)-(\d+)-(\d+) (\d+):(\d+):(\d+)(?:(\.\d+))?([+-]\d+)?$/
          raise ArgumentError.new("Cannot parse time string: #{s.inspect}")
        end

        year, mon, day = $1, $2, $3
        hour, mins, secs, msecs = $4, $5, $6, ($7? || '0')

        offset = $8?

        time = Time.new(year.to_i, mon.to_i, day.to_i, hour.to_i, mins.to_i, secs.to_i, (1000 * ("" + msecs).to_f), Time::Kind::Utc)
        time -= offset.to_i.hours if offset
        time
      end
    end

    class UuidDecoder < Decoder
      def decode_string(s)
        s
      end
    end

    class ByteaDecoder < Decoder
      NULL_CHAR = '0'.ord
      A_CHAR = 'A'.ord
      LOWER_A_CHAR = 'a'.ord

      def hexchar2num(ch)
        if ch < (NULL_CHAR + 10)
          ch - NULL_CHAR
        elsif ch < A_CHAR + 6
          ch - A_CHAR + 10
        elsif ch < LOWER_A_CHAR + 6
          ch - LOWER_A_CHAR + 10
        else
          raise ArgumentError.new
        end
      end

      def decode(bytes)
        # assume "\\x", then start conversion of 2 hexchars into a single byte
        bytes += 2
        r = [] of UInt8

        while bytes.size > 1
          b0 = bytes[0]
          b1 = bytes[1]

          r << hexchar2num(b0) * 16 + hexchar2num(b1)
          bytes += 2
        end

        r
      end
    end

    @@decoders = Hash(Int32, PG::Decoder::Decoder).new(DefaultDecoder.new)

    def self.register_decoder(decoder, oid)
      @@decoders[oid] = decoder
    end

    def self.decode(oid, slice)
      @@decoders[oid].decode(slice)
    end

    # https://github.com/postgres/postgres/blob/master/src/include/catalog/pg_type.h
    register_decoder BoolDecoder.new, 16     # bool
    register_decoder ByteaDecoder.new, 17    # bytea
    register_decoder Int8Decoder.new, 20     # int8 (bigint)
    register_decoder Int2Decoder.new, 21     # int2 (smallint)
    register_decoder IntDecoder.new, 23      # int4 (integer)
    register_decoder DefaultDecoder.new, 25  # text
    register_decoder JsonDecoder.new, 114    # json
    register_decoder JsonbDecoder.new, 3802  # jsonb
    register_decoder Float32Decoder.new, 700 # float4
    register_decoder Float64Decoder.new, 701 # float8
    register_decoder NumericDecoder.new, 1700 # numeric
    register_decoder MoneyDecoder.new, 790   # money
    register_decoder DefaultDecoder.new, 705 # unknown
    register_decoder DateDecoder.new, 1082   # date
    register_decoder TimeDecoder.new, 1114   # timestamp
    register_decoder TimeDecoder.new, 1184   # timestamptz
    register_decoder UuidDecoder.new, 2950   # uuid
  end
end
