require_relative "parser/jpt-util.rb"

class JPT
  @@parser = JPTGRAMMARParser.new

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
