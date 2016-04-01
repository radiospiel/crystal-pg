module PG
  class Result(T)
    struct Row
      def initialize(@result, @row)
      end

      def each
        @result.fields.each_with_index do |field, col|
          yield field.name, @result.decode_value(@row, col)
        end
      end
    end

    struct Field
      property name
      property oid

      def initialize(@name, @oid)
      end

      def self.new_from_res(res, col)
        new(
          String.new(LibPQ.fname(res, col)),
          LibPQ.ftype(res, col)
        )
      end
    end

    def initialize(@types : T, @res, @result_format)
    end

    def finalize
      LibPQ.clear(res)
    end

    def each
      ntuples.times { |i| yield Row.new(self, i) }
    end

    def fields
      @fields ||= Array.new(nfields) do |i|
        Field.new_from_res(res, i)
      end
    end

    def rows
      @rows ||= gather_rows(@types)
    end

    def any?
      ntuples > 0
    end

    def to_hash
      field_names = fields.map(&.name)

      if field_names.uniq.size != field_names.size
        raise PG::RuntimeError.new("Duplicate field names in result set")
      end

      rows.map do |row|
        Hash.zip(field_names, row.to_a)
      end
    end

    private getter res

    private def ntuples
      LibPQ.ntuples(res)
    end

    private def nfields
      LibPQ.nfields(res)
    end

    private def gather_rows(types : Array(PGValue))
      Array.new(ntuples) do |i|
        Array.new(nfields) do |j|
          decode_value(i, j)
        end
      end
    end

    macro generate_gather_rows(from, to)
      {% for n in (from..to) %}
        private def gather_rows(types : Tuple({% for i in (1...n) %}Class, {% end %} Class))
          Array.new(ntuples) do |i|
            { {% for j in (0...n) %} types[{{j}}].cast( decode_value(i, {{j}}) ), {% end %} }
          end
        end
      {% end %}
    end

    generate_gather_rows(1, 32)

    protected def decode_value(row, col)
      val_ptr = LibPQ.getvalue(res, row, col)
      if val_ptr.value == 0 && LibPQ.getisnull(res, row, col)
        nil
      else
        size = LibPQ.getlength(res, row, col)
        if @result_format == :text
          PG::TextDecoder.decode(fields[col].oid, val_ptr.to_slice(size))
        else
          PG::Decoder.decode(fields[col].oid, val_ptr.to_slice(size))
        end
      end
    end
  end
end
