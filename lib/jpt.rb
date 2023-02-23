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

  def apply(arg)
    nodes = [arg]
    select_query(tree, nodes, nodes, :error)
  end

  def select_query(tree, nodes, root_node, curr_node)
    case tree
    in ["$", *segments]
      nodes = root_node
      segments.each do |seg|
        nodes = select_segment(seg, nodes, root_node, curr_node)
      end
    in ["@", *segments]
      nodes = curr_node
      segments.each do |seg|
        nodes = select_segment(seg, nodes, root_node, curr_node)
      end
    end
    nodes
  end

  def select_segment(seg, nodes, root_node, curr_node)
    case seg
    in Integer => ix
      nodes = nodes.flat_map do |n|
        if Array === n
         [n.fetch(ix, :nothing)]
        else []
        end
      end
    in String => ky
      nodes = nodes.flat_map do |n|
        if Hash === n
          [n.fetch(ky, :nothing)]
        else []
        end
      end
    in ["u", *sel]
#      nodes = sel.flat_map{ |sel1| select_segment(sel1, nodes, root_node, curr_node)}
      nodes = nodes.flat_map do |n|
        sel.flat_map{ |sel1| select_segment(sel1, [n], root_node, curr_node)}
      end
    in ["wild"]
      nodes = nodes.flat_map do |n|
        enumerate(n)
      end
    in ["desc", sel]
      nodes = nodes.flat_map do |n|
        containers(n)
      end
      nodes = select_segment(sel, nodes, root_node, curr_node)
    in ["slice", st, en, sp]
      nodes = nodes.flat_map do |n|
        if (Array === n) && sp != 0
          len = n.length
          ret = []
          sp ||= 1
          if sp > 0             # weird formulae copied from spec
            st ||= 0
            en ||= len
          else
            # warn "ARR #{st} #{en} #{sp}"
            st ||= len - 1
            en ||= -len - 1
            # warn "ARR2 #{st} #{en} #{sp}"
          end
          st, en = [st, en].map{|i| i >= 0 ? i : len + i}
          if sp > 0
            lo = [[st, 0].max, len].min
            up = [[en, 0].max, len].min
            while lo < up
              ret << n[lo]; lo += sp
            end
          else
            up = [[st, -1].max, len-1].min
            lo = [[en, -1].max, len-1].min
            # warn "ARR3 #{st} #{en} #{sp} #{lo} #{up}"
            while lo < up
              ret << n[up]; up += sp
            end
          end
          ret
        else
          []
        end
      end
    in ["filt", logexp]
      nodes = nodes.flat_map do |n|
        enumerate(n).flat_map do |cand|
          a = filt_apply(logexp, root_node, [cand])
          # warn "***A #{a.inspect}"
          if filt_to_logical(a)
            [cand]
          else
            []
          end
        end
      end
    end
    nodes.delete(:nothing)
    nodes
  end

  def enumerate(n)
    case n
    in Array
      n
    in Hash
      n.map{|k, v| v}
    else
      []
    end
  end

  def containers(n)
    case n
    in Array
      [n, *n.flat_map{containers(_1)}]
    in Hash
      [n, *n.flat_map{|k, v| containers(v)}]
    else
      []
    end
  end

  def filt_to_logical(val)
    case val
    in [:nodes, v]
      v != []
    in [:logical, v]
      v
    end
  end

  def filt_to_value(val)
    case val
    in [:nodes, v]
      if v.length == 1
        v[0]
      else
        :nothing
      end
    in [:value, v]
      v
    end
  end

  COMPARE_SWAP = {">" => "<", ">=" => "<="}

  def filt_apply(logexp, root_node, curr_node)
    # warn "***B #{logexp.inspect} #{root_node.inspect} #{curr_node.inspect}"
    case logexp
    in ["@", *]
      [:nodes, select_query(logexp, curr_node, root_node, curr_node)]
    in ["$", *]
      [:nodes, select_query(logexp, root_node, root_node, curr_node)]
    in [("==" | "!=" | "<" | ">" | "<=" | ">="), a, b]
      lhs = filt_to_value(filt_apply(a, root_node, curr_node)) rescue :nothing
      rhs = filt_to_value(filt_apply(b, root_node, curr_node)) rescue :nothing
      op = logexp[0]
      # warn "***C #{op} #{lhs.inspect}, #{rhs.inspect}"
      if sop = COMPARE_SWAP[op]
        lhs, rhs = rhs, lhs
        op = sop
      end
      # warn "***C1 #{op} #{lhs.inspect}, #{rhs.inspect}"
      res = if op != "<" && (lhs == rhs rescue false)
              op == "!=" ? false : true
            else
              if op[0] == "<"   # "<" or "<="
                case [lhs, rhs]
                in Numeric, Numeric
                  lhs < rhs
                in String, String
                  lhs < rhs
                else
                  false
                end
              else op == "!="
              end
            end
      # warn "***C9 #{res}"
      [:logical, res]
    in ["and" | "or", a, b]
      lhs = filt_to_logical(filt_apply(a, root_node, curr_node))
      rhs = filt_to_logical(filt_apply(b, root_node, curr_node))
      op = logexp[0]
      # warn "***C #{op} #{lhs.inspect}, #{rhs.inspect}"
      [:logical, case op
                 in "or"
                   lhs || rhs
                 in "and"
                   lhs && rhs
                 end]
    in ["not", a]
      lhs = filt_to_logical(filt_apply(a, root_node, curr_node))
      [:logical, !lhs]
    in ["func", "length", value]
      value = filt_to_value(filt_apply(value, root_node, curr_node))
      [:value,
       case value
       in Hash | Array | String
         value.length
       else
         :nothing
       end
      ]
    in ["func", "count", nodes]
      ty, nodes = filt_apply(nodes, root_node, curr_node)
      [:value,
       if ty != :nodes
         warn "*** func count ty #{ty.inspect}"
         0
       else
         nodes.length
       end]
    in ["func", "match", str, re]
      str = filt_to_value(filt_apply(str, root_node, curr_node))
      re = filt_to_value(filt_apply(re, root_node, curr_node))
      [:logical,
       begin
         /\A(?:#{re})\z/ === str
       rescue => e
         warn "*** #{e.detailed_message} #{e.backtrace}"
         false
       end
      ]
    in ["func", "search", str, re]
      str = filt_to_value(filt_apply(str, root_node, curr_node))
      re = filt_to_value(filt_apply(re, root_node, curr_node))
      [:logical,
       begin
         /#{re}/ === str
       rescue => e
         warn "*** #{e.detailed_message} #{e.backtrace}"
         false
       end
      ]
    in ["func", name, *args]
      warn "*** Unknown function extension #{name} with args #{args.inspect}"
      [:logical, false]
    in String | Numeric | false | true | nil
      [:value, logexp]
    end
  end
end
