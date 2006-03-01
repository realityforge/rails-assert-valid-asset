desc "Cleanup Backup files"
task :clear_backup => :environment do
  Dir["#{RAILS_ROOT}/**/*.*~"].each {|file| File.delete(file)}
end

desc "Cleanup temporary files"
task :clear_temp => :environment do
  Dir.glob("#{RAILS_ROOT}/temp/*") {|f| FileUtils.rm_r(f, :force => true) unless f == '.svn'}
end

desc "Cleanup temporary and intermediate files"
task :clear => [:clear_backup, :clear_temp, :clear_logs] do
end
