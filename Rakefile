task :default => :build

task :build => "lib/parser/jptgrammar.rb" do
  sh "gem build jpt.gemspec"
end

file "lib/parser/jptgrammar.rb" => "lib/parser/jptgrammar.treetop" do
  sh 'LANG="en_US.utf-8" tt lib/parser/jptgrammar.treetop'
end

file "lib/parser/jptgrammar.treetop" => "lib/parser/jptgrammar.abnftt" do
  sh "abnftt lib/parser/jptgrammar.abnftt"
  sh "diff lib/parser/jptgrammar.abnf lib/parser/jpt.abnf.orig"
end

task :linetest => :build do
  sh "bin/jpt -l test-data/test.jpl"
end
