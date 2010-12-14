%w[sequel-3.18.0
json-1.4.6
sinatra-1.1.0
haml-3.0.24
archive-zip-0.3.0
tilt-1.1
io-like-0.3.0
].each{|gem| $:.unshift "/home/zverok/.gems/gems/#{gem}/lib/"}



require 'rubygems'
require 'sequel'

Sequel::Model.db = Sequel.mysql 'friendfeed_dwl',
						:user => 'friendfeed_dwl',
						:host => 'mysql.dwldr.com',
						:password => 'IUf2KYVo87gb3t',
						:encoding => 'utf8'

$:.unshift File.join(File.dirname(__FILE__), 'app')
$:.unshift File.join(File.dirname(__FILE__), 'lib')
require 'models'
require 'clio'

run Clio::App
