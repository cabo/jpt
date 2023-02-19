require 'treetop'
require_relative './jptgrammar'

class Treetop::Runtime::SyntaxNode
  def ast
    fail "undefined_ast #{inspect}"
  end
  def ast1                      # devhack
    "#{inspect[10..20]}--#{text_value[0..15]}"
  end
  def repwrap(el, val)
    if el.text_value == ''
      val
    else
      ["rep", *el.ast, val]
    end
  end
end
