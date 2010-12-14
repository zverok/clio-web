$KCODE='u'
$:.unshift File.join(File.dirname(__FILE__), '..', 'app')
$:.unshift File.join(File.dirname(__FILE__), '..', 'lib')

require 'rubygems'
require 'sequel'
require 'core_ext'
require 'logger'
require 'pp'
$l = Logger.new(STDOUT)
$l.level = Logger::FATAL

Sequel::Model.db = Sequel.mysql 'friendfeed_dwl',
						:user => 'friendfeed_dwl',
						:password => 'IUf2KYVo87gb3t',
						:encoding => 'utf8',
						:logger => $l

require 'models'

include Clio
include Models
Index.all.each{|i| i.to_file(File.dirname(__FILE__))}
