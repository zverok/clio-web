require 'rubygems'
require 'sinatra'
require 'haml'
require 'archive/zip'

require 'frf_client'

module Clio
	INDEXES = [Models::DateIndex, Models::HashtagIndex, Models::AllIndex]

	class App < Sinatra::Base
		get '/' do
			haml :index
		end
		
		BASE_PATH = File.expand_path(File.join(File.dirname(__FILE__), '..'))
		RESULT_PATH = File.join(BASE_PATH, 'result')
		STATIC_PATH = File.join(BASE_PATH, 'templates')
		ARCHIVES_PATH = File.join(BASE_PATH, 'public', 'zip')
		
		post '/' do
			user = feed = params[:username]
			key = params[:key]
		
			save_path = File.join(RESULT_PATH, user, feed)

			# 1. extract feed, saving entry files and indexing entries to DB
			Models::Index.filter(:user => user, :feed => feed).delete
			indexes = INDEXES.map{|klass| klass.create(:user => user, :feed => feed, :created_at => Time.now)}

			FriendFeedClient.extract_feed(
				:login => user, 
				:key => key, 
				:feed => feed, 
				:path => save_path,
				:indexes => indexes)

			# 2. save indexes to files
			Models::Index.filter(:user => user, :feed => feed).each do |idx|
				idx.save(File.join(save_path, 'data', 'indexes'))
			end
			
			# 3. copy static content
			Dir[File.join(STATIC_PATH, '**', '*.*')].each do |src|
				tgt = src.sub(STATIC_PATH, save_path)
				FileUtils.makedirs File.dirname(tgt)
				FileUtils.cp src, tgt
			end
			
			# 4. zip
			Archive::Zip.archive(File.join(ARCHIVES_PATH, "#{user}.zip"), save_path)
			
			# 5. show link to result
			@link = "/zip/#{user}.zip"
			haml :result
		end
	end
end
