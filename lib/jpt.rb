module JPTType
  # :value, :nodes, :logical


  FUNCSIG_CHARS = {"l" => :logical, "n" => :nodes, "v" => :value}

  FUNCTABLE = {
    "length" => [:value, :value],
    "count" => [:value, :nodes],
    "match" => [:logical, :value, :value],
    "search" => [:logical, :value, :value],
  }

  def self.add_funcsig(name, sig)
    FUNCTABLE[name] = sig.chars.map {FUNCSIG_CHARS[_1]}
  end

  def declared_type(ast)
    case ast
    in Numeric | String | false | true | nil
      :value
    in ["@", *] | ["$", *]
      :nodes
    in ["func", funcname, *funcargs]
      ret, *parms = FUNCTABLE[funcname]
      if parms.length != funcargs.length
        warn "*** Incorrect number of arguments #{ast} #{parms.inspect} #{funcargs.inspect}"
      else
        parms.zip(funcargs).each do |pm, ar|
          declared_as(ar, pm, " in #{ast}") # XXX overhead
        end
      end
      ret
    end
  end

  def declared_as(ast, rt, s = "")
    dt = declared_type(ast)
    case [dt, rt]
    in a, b if a == b
      true
    in [:nodes, :value] | [:nodes, :logical]
      true
    else
      warn "*** Cannot use #{ast} with declared_type #{dt||:undefined} for required type #{rt}#{s}"
      false
    end
  end
end

require_relative "parser/jpt-util.rb"

class JPT
  @@parser = JPTGRAMMARParser.new
  include ::JPTType

  DATA_DIR = Pathname.new(__FILE__) + "../../data/"

  def self.reason(parser, s)
    reason = [parser.failure_reason]
    parser.failure_reason =~ /^(Expected .+) after/m
    reason << "#{$1.gsub("\n", '<<<NEWLINE>>>')}:" if $1
    if line = s.lines.to_a[parser.failure_line - 1]
      reason << line
      reason << "#{'~' * (parser.failure_column - 1)}^"
    end
    reason.join("\n")
  end

  SAFE_FN = /\A[-._a-zA-Z0-9]+\z/

  def self.from_jp(s)
    ast = @@parser.parse s
    if !ast
      fail self.reason(@@parser, s)
    end
    ret = JPT.new(ast)

    ret
  end

  attr_accessor :ast, :tree, :directives
  def initialize(ast_)
    @ast = ast_
    @tree = ast.ast
  end

  def deep_clone
    Marshal.load(Marshal.dump(self))
  end

end
