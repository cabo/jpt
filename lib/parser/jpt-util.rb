require 'treetop'
require_relative './jptgrammar'
require_relative '../jpt'

class Treetop::Runtime::SyntaxNode
  include ::JPTType
  def ast
    fail "undefined_ast #{inspect}"
  end
  def ast1                      # devhack
    "#{inspect[10..20]}--#{text_value[0..15]}"
  end
end
