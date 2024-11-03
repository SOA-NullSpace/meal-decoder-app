# frozen_string_literal: true

def require_app(folders = %w[domain infrastructure views controllers])
  require_relative 'app/domain/values/types'
  require_folder_files(folders)
end

def require_folder_files(folders)
  full_list = generate_folder_list(folders)
  load_files_in_order(full_list)
end

def generate_folder_list(folders)
  app_folders = Array(folders).map { |folder| "app/#{folder}" }
  ['config', app_folders].flatten.join(',')
end

def load_files_in_order(folder_list)
  Dir.glob("./{#{folder_list}}/**/*.rb")
     .sort
     .reject { |file| file.include? 'values/types.rb' }
     .each { |file| require file }
end