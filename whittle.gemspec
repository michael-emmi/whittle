# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "whittle/version"

Gem::Specification.new do |s|
  s.name        = "whittle"
  s.version     = Whittle::VERSION.sub(/-.*-/,'-').sub('++','')
  s.licenses    = ['MIT']
  s.authors     = ['Michael Emmi']
  s.email       = 'michael.emmi@gmail.com'
  s.homepage    = 'https://github.com/michael-emmi/whittle'
  s.summary     = "Whittle reduces files."
  s.description = File.read('README.md').lines.drop(1).take_while{|line| line !~ /##/}.join.strip
  s.files       = `git ls-files`.split("\n")
  s.executables = ['whittle']
  s.require_path = 'lib'
end
