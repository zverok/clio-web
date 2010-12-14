require 'sequel'
require 'cgi'
require 'json'

Sequel::Model.plugin :schema

module Clio
	module Models
		class IndexRowEntry < Sequel::Model(:index_row_entries)
			set_schema do
				primary_key :id
				foreign_key :row_id
				
				varchar :date
				varchar :name
			end
			
			dataset.order!(:date.desc)
		end

		class IndexRow < Sequel::Model(:index_rows)
			set_schema do
				primary_key :id
				foreign_key :index_id
				
				varchar :descriptor, :size => 30
				varchar :title, :size => 50
				varchar :group, :size => 30
				
				index :index_id
				index [:index_id, :group]
				
				index [:index_id, :descriptor, :title, :group]
			end
			
			dataset.order!(:descriptor)
			
			def to_hash
				{'descriptor' => CGI.escape(descriptor),
				'title' => title,
				'entries' => entries.map(&:name)}
			end

			one_to_many :entries, :class => IndexRowEntry, :key => :row_id
		end

		class Index < Sequel::Model(:indexes)
			set_schema do
				primary_key :id

				varchar :kind_class
				
				varchar :user
				varchar :feed
				
				datetime :created_at
			end
			
			one_to_many :rows, :class => IndexRow
			
			plugin :single_table_inheritance, :kind_class
			
			def initialize(*a)
				super
				@rows = Hash.new{|h, k| h[k] = {'descriptor' => k, 'entries' => []} }
				#@subindexes = Hash.new{|h,k| h[k] = subindex.new(k)}
			end
			
			def put(entry)
				parse(entry).each do |descriptor, title|
					row = IndexRow.find_or_create(:index_id => self.id, :descriptor => descriptor, :title => title, :group => group_by(descriptor))
					IndexRowEntry.create(:row_id => row.id, :date => entry['date'], :name => entry['name'])
					
					#if has_subindexes?
						#@subindexes[descriptor].put(entry) 
						#@rows[descriptor]['subindex'] ||= @subindexes[descriptor].descriptor
					#end
				end
			end
			
			def result
				if grouped?
					row_groups = rows_dataset.naked.select(:distinct[:group].as(:group)).order(:group).map(:group)
					
					{
						'meta' => {'descriptor' => descriptor, 'title' => title, 'kind' => 'grouped'},
						'groups' => row_groups.map{|g| {'title' => g, 'rows' => rows_dataset.filter(:group => g).all.map(&:to_hash)}}
					}
				else
					{
						'meta' => {'descriptor' => descriptor, 'title' => title, 'kind' => 'plain'},
						'rows' => rows.map(&:to_hash)
					}
				end
			end
			
			def to_file(base_path)
				#@subindexes.values.each{|si| si.save(base_path)}
				File.write(File.join(base_path, descriptor + '.js'), result.to_json)
			end
			
			private
			
			def parse(entry)
				[key(entry)].flatten.map{|key|
					[row_descriptor(key), row_title(key)]
				}
			end
			
			def key(entry); end
			def row_descriptor(key); key end
			def row_title(key); row_descriptor(key) end
			
			def grouped?; false end
			def group_by(descriptor); nil end
			def has_subindexes?; not subindex.nil? end
			def subindex; nil end

			def parse_time(str)
				str =~ /(\d+)-(\d+)-(\d+)T(\d+):(\d+):(\d+)Z/
				Time.local($1, $2, $3, $4, $5, $6)
			end
		end
		
		[Index, IndexRow, IndexRowEntry].each do |tbl|
			tbl.create_table unless tbl.table_exists?
		end

		class DateIndex < Index
			def descriptor; 'dates' end
			def title; 'Месяцы' end
			
			def key(entry); parse_time(entry['date']) end
			def row_descriptor(tm); tm.strftime('%Y-%m') end
			def row_title(tm); tm.strftime('%B') end
			
			def grouped?; true end
			def group_by(descriptor); descriptor.split('-', 2).first end
			
			def subindex; MonthDaysIndex end
		end


		class HashtagIndex < Index
			def descriptor; 'hashtags' end
			def title; 'Теги' end
			
			def key(entry)
				extract_hashtags(entry['body']) + 
					(entry['comments'] || []).map{|c| extract_hashtags(c['body'])}.flatten
			end

			def extract_hashtags(str)
				str.scan(%r{<a href="http://friendfeed.com/search\?q=[^>]+>#(.+?)</a>}).flatten.map{|ht| ht.gsub('_', ' ')}
			end
		end

		class MonthDaysIndex < Index
			def month_descriptor=(d)
				@month = Time.local(*(month_descriptor + '-01').split('-'))
			end
			
			def descriptor; "days__#{@month.strftime('%Y-%m')}" end
			def title; @month.strftime('%B %Y') end
			
			def key(entry); parse_time(entry['date']) end
			def row_descriptor(tm); tm.strftime('%d') end
		end

		class AllIndex < Index
			def descriptor; 'all' end
			def title; 'Все' end
			
			def key(entry)
				'all'
			end
		end
	end
end
