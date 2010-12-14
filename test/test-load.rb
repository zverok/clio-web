$KCODE='u'
$:.unshift File.join(File.dirname(__FILE__), '..', 'app')
$:.unshift File.join(File.dirname(__FILE__), '..', 'lib')

require 'rubygems'
require 'sequel'
require 'core_ext'
require 'logger'
$l = Logger.new(STDOUT)
$l.level = Logger::FATAL

Sequel::Model.db = Sequel.mysql 'friendfeed_dwl',
						:user => 'friendfeed_dwl',
						:password => 'IUf2KYVo87gb3t',
						:encoding => 'utf8',
						:logger => $l

require 'models'
require 'frf_client'

include Clio
include Models
INDEXES = [DateIndex, HashtagIndex, AllIndex]
user, key, feed = 'zverok', nil, 'zverok'
Index.filter(:user => user, :feed => feed).delete
indexes = INDEXES.map{|klass| klass.create(:user => user, :feed => feed, :created_at => Time.now)}
save_path = File.join(File.dirname(__FILE__), 'tmp')

FriendFeedClient.extract_feed(
	:login => user, 
	:key => key, 
	:feed => feed, 
	:path => save_path,
	:indexes => indexes)
