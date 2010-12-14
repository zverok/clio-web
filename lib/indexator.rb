# encoding: utf-8
require 'json'
require 'core_ext'

require 'rutils/datetime/datetime'

#define_list 'all' do
    #title 'Все'
    #reverse_sort_by{|entry| entry['date']}
#end

#define_list 'most_commented' do
    #title 'Топ по комментариям'
    #reverse_sort_by{|entry| entry['comments'].size}
#end

#define_list 'most_liked' do
    #title 'Топ по лайкам'
    #reverse_sort_by{|entry| entry['likes'].size}
#end
